from firebase_functions import https_fn, firestore_fn
from firebase_admin import initialize_app, firestore, messaging
from google import genai
from google.genai import types
from google.cloud.firestore_v1 import FieldFilter
import json
from datetime import datetime, timezone, timedelta
from section_parser import parse_sections

initialize_app()

PROJECT_ID = "newsletters-c8650"
LOCATION = "us-central1"
DEFAULT_SECTIONS = [
    "Business & Finance", "Startups & Venture Capital", "Artificial Intelligence",
    "US Politics", "World Politics", "Healthcare", "Science", "Technology",
    "Climate & Environment", "Culture & Entertainment", "Sports", "Other"
]

# Sender map cache (loaded from Firestore Config/newsletters on first use per invocation)
_sender_map_cache: dict | None = None


def _load_sender_map(db) -> dict:
    """Load the newsletter config from Config/newsletters in Firestore.

    The document is keyed by sender ID with fields:
        { "emails": ["email@domain"], "displayName": "Display Name", "group": "...", "sortOrder": N }

    Returns a dict: { email_address: { "senderId": str, "displayName": str } }
    """
    global _sender_map_cache
    if _sender_map_cache is not None:
        return _sender_map_cache

    doc = db.collection("Config").document("newsletters").get()
    email_map = {}
    if doc.exists:
        data = doc.to_dict()
        for sender_id, info in data.items():
            display_name = info.get("displayName", sender_id)
            for email in info.get("emails", []):
                email_map[email.lower()] = {
                    "senderId": sender_id,
                    "displayName": display_name,
                }
    _sender_map_cache = email_map
    return email_map


def resolve_sender_id(sender: str, db=None) -> str | None:
    """Map a sender string like 'Name <email@domain>' to a sender ID."""
    if db is None:
        db = firestore.client()
    email = _extract_email(sender)
    sender_map = _load_sender_map(db)
    entry = sender_map.get(email)
    return entry["senderId"] if entry else None


def resolve_sender_display_name(sender: str, db=None) -> str | None:
    """Map a sender string to a display name via the sender map."""
    if db is None:
        db = firestore.client()
    email = _extract_email(sender)
    sender_map = _load_sender_map(db)
    entry = sender_map.get(email)
    return entry["displayName"] if entry else None


# Schema for story extraction from a single newsletter
STORY_EXTRACTION_SCHEMA = {
    "type": "object",
    "properties": {
        "stories": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "headline": {"type": "string"},
                    "description": {"type": "string"},
                    "categories": {
                        "type": "array",
                        "items": {"type": "string"}
                    },
                    "sectionIndex": {"type": "integer"},
                    "positionRank": {"type": "integer"},
                    "imageUrls": {
                        "type": "array",
                        "items": {"type": "string"}
                    },
                    "matchesExistingStoryId": {"type": "string"}
                },
                "required": ["headline", "description", "categories", "sectionIndex", "positionRank"]
            }
        }
    },
    "required": ["stories"]
}

# Default source prominence weights (used if Config/sourceProminence not yet seeded)
DEFAULT_PROMINENCE = {
    "nytTheMorning": 1.0, "nytBreakingNews": 1.0,
    "morningBrew": 0.8, "techBrew": 0.7, "itBrew": 0.7,
    "sigmaXiSmartBrief": 0.6, "heated": 0.6,
    "evolvingAI": 0.5, "historyFacts": 0.4, "ceoReport": 0.5,
}


def extract_display_name(sender: str) -> str:
    """Extract display name from 'Name <email@domain>' format."""
    if "<" in sender:
        return sender.split("<")[0].strip().strip('"')
    return sender.strip()



@https_fn.on_call(region="us-central1", memory=512, timeout_sec=300)
def generateDigest(req: https_fn.CallableRequest) -> dict:
    if req.auth is None:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="Request must be authenticated."
        )

    uid = req.auth.uid
    db = firestore.client()
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    now_iso = datetime.now(timezone.utc).isoformat()

    # Step 1: Read user's enabledNewsletters (sender IDs)
    prefs_ref = (db.collection("users").document(uid)
                   .collection("settings").document("preferences"))
    prefs_doc = prefs_ref.get()

    if not prefs_doc.exists:
        return _write_empty_and_return(db, uid, today, now_iso)

    enabled_senders = set(prefs_doc.to_dict().get("enabledNewsletters", []))
    if not enabled_senders:
        return _write_empty_and_return(db, uid, today, now_iso)

    # Step 2: Read today's NewsletterMetadata, filter by enabled senders
    today_start = datetime.now(timezone.utc).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    today_end = today_start + timedelta(days=1)

    meta_docs = (db.collection("NewsletterMetadata")
                   .where("newsletterDate", ">=", today_start)
                   .where("newsletterDate", "<", today_end)
                   .stream())

    newsletters = []
    for doc in meta_docs:
        data = doc.to_dict()
        sender = data.get("sender", "")
        sender_id = resolve_sender_id(sender, db)
        if sender_id and sender_id in enabled_senders:
            newsletters.append({
                "id": doc.id,
                "sender": sender,
                "senderId": sender_id,
            })

    if not newsletters:
        return _write_empty_and_return(db, uid, today, now_iso)

    # Step 3: Assemble digest from pre-extracted stories
    stories_digest = _assemble_digest_from_stories(
        db, today, enabled_senders, now_iso, newsletters
    )
    if not stories_digest:
        print(f"generateDigest: no stories found for {today} — this is unexpected")
        return _write_empty_and_return(db, uid, today, now_iso)

    (db.collection("users").document(uid)
       .collection("digests").document(today)
       .set(stories_digest))

    return stories_digest


def _assemble_digest_from_stories(
    db,
    today: str,
    enabled_senders: set[str],
    now_iso: str,
    newsletters: list[dict],
) -> dict | None:
    """Build a digest from the pre-extracted stories collection.

    Returns a digest dict if stories exist, or None to trigger the Gemini fallback.
    """
    stories_docs = list(db.collection("stories").where("date", "==", today).stream())
    if not stories_docs:
        return None

    # Filter to stories where at least one source matches the user's enabled senders
    filtered = []
    for sdoc in stories_docs:
        sdata = sdoc.to_dict()
        sdata["_id"] = sdoc.id
        sources = sdata.get("sources", [])
        if any(s.get("senderId") in enabled_senders for s in sources):
            filtered.append(sdata)

    if not filtered:
        return None

    # Sort by magnitude descending
    filtered.sort(key=lambda s: s.get("magnitude", 0), reverse=True)

    # Top stories (up to 5)
    top_stories = [_story_to_digest_item(s) for s in filtered[:5]]

    # Group remaining into category sections, sorted by magnitude within each
    category_buckets: dict[str, list] = {}
    for story in filtered:
        categories = story.get("categories", ["Other"])
        primary = categories[0] if categories else "Other"
        category_buckets.setdefault(primary, []).append(story)

    sections_data = []
    for title, stories in category_buckets.items():
        stories.sort(key=lambda s: s.get("magnitude", 0), reverse=True)
        items = [_story_to_digest_item(s) for s in stories]
        sections_data.append({"title": title, "items": items})

    return {
        "generatedAt": now_iso,
        "newsletterCount": len(newsletters),
        "newsletterIds": [nl["id"] for nl in newsletters],
        "sections": sections_data,
        "topStories": top_stories,
    }


def _story_to_digest_item(story: dict) -> dict:
    """Convert a story document to a digest item dict."""
    sources = []
    for s in story.get("sources", []):
        sources.append({
            "newsletterId": s.get("newsletterId", ""),
            "displayName": s.get("displayName", ""),
            "senderId": s.get("senderId", ""),
            "sectionIndex": s.get("sectionIndex"),
        })
    return {
        "headline": story.get("headline", ""),
        "description": story.get("description", ""),
        "storyId": story.get("_id", ""),
        "magnitude": story.get("magnitude", 0),
        "sources": sources,
        "images": story.get("images", []),
    }


def _write_empty_and_return(db, uid: str, today: str, now_iso: str) -> dict:
    doc_data = {"generatedAt": now_iso, "newsletterCount": 0, "newsletterIds": [], "sections": []}
    (db.collection("users").document(uid)
       .collection("digests").document(today)
       .set(doc_data))
    return doc_data


def _extract_email(sender: str) -> str:
    """Extract email address from 'Name <email@domain>' format."""
    if "<" in sender and ">" in sender:
        return sender.split("<")[1].rstrip(">").strip().lower()
    if "@" in sender:
        return sender.strip().lower()
    return ""


@firestore_fn.on_document_created(
    document="NewsletterMetadata/{docId}",
    region="us-central1"
)
def notifyNewsletter(
    event: firestore_fn.Event[firestore_fn.DocumentSnapshot | None]
) -> None:
    if event.data is None:
        return

    data = event.data.to_dict()
    sender = data.get("sender", "")
    subject = data.get("subject", "New newsletter")
    display_name = extract_display_name(sender)

    db = firestore.client()
    sender_id = resolve_sender_id(sender, db)

    if not sender_id:
        return

    # Find users with notifications enabled for this sender ID
    try:
        prefs_query = (db.collection_group("settings")
                         .where(filter=FieldFilter("notificationNewsletters", "array-contains", sender_id)))
        docs = list(prefs_query.stream())
    except Exception as e:
        print(f"Notification query failed: {e}")
        return

    for doc in docs:
        token = doc.to_dict().get("fcmToken")
        if not token:
            continue
        try:
            messaging.send(messaging.Message(
                notification=messaging.Notification(
                    title=display_name,
                    body=subject
                ),
                token=token
            ))
        except Exception as e:
            print(f"FCM send error for token {token[:10]}...: {e}")


# ---------------------------------------------------------------------------
# Story extraction
# ---------------------------------------------------------------------------

def build_extraction_prompt(
    sections: list,
    sender_id: str,
    display_name: str,
    categories: list[str],
    existing_stories: list[dict],
) -> str:
    """Build the Gemini prompt for extracting stories from one newsletter."""
    sections_block = "\n\n".join(
        f"[Section {s.index}]\n{s.plain_text}" for s in sections
    )
    categories_str = ", ".join(categories)

    existing_block = ""
    if existing_stories:
        lines = [f'  - id="{s["id"]}": {s["headline"]}' for s in existing_stories]
        existing_block = (
            "\n\nEXISTING STORIES (for deduplication — if an extracted story covers "
            "the same event as one below, set matchesExistingStoryId to its id):\n"
            + "\n".join(lines)
        )

    return f"""You are extracting news stories from a newsletter.

SOURCE: [{sender_id}|{display_name}]

SECTIONS:
{sections_block}

INSTRUCTIONS:
- Extract each distinct news story from the newsletter sections above
- For each story provide: headline, 1-2 sentence description, categories (from: {categories_str}), the sectionIndex where the story appears, its positionRank (1 = first story, 2 = second, etc.), and any image URLs found in that section
- A story may belong to multiple categories
- Ignore advertising, sponsored content, promotional sections, calls to action, table of contents, and editor's notes
- Filter out tracking pixels, logos, and ad images — only include substantive content images (photos, charts, infographics)
- Keep descriptions factual and concise (1-2 sentences)
- If a story matches an existing story below, set matchesExistingStoryId to that story's id. Otherwise omit the field.
{existing_block}

Output valid JSON matching the provided schema."""


def calculate_magnitude(
    sources: list[dict],
    total_newsletters_today: int,
    prominence_weights: dict[str, float],
) -> float:
    """Compute magnitude score (0.0-1.0) from source count, prominence, and position."""
    if not sources:
        return 0.0
    source_count_score = min(len(sources) / max(total_newsletters_today, 1), 1.0)
    prominence_score = max(
        prominence_weights.get(s.get("senderId", ""), 0.5) for s in sources
    )
    avg_position = sum(s.get("positionRank", 5) for s in sources) / len(sources)
    position_score = 1.0 - min(avg_position - 1, 10) / 10
    return round(0.40 * source_count_score + 0.35 * prominence_score + 0.25 * position_score, 4)


def _recalculate_all_magnitudes_today(
    db, today: str, prominence_weights: dict, total_newsletters: int
):
    """Recalculate magnitude for all of today's stories (denominator changed)."""
    stories = db.collection("stories").where("date", "==", today).stream()
    for story_doc in stories:
        story = story_doc.to_dict()
        new_mag = calculate_magnitude(
            story.get("sources", []), total_newsletters, prominence_weights
        )
        if abs(new_mag - story.get("magnitude", 0)) > 0.001:
            story_doc.reference.update({
                "magnitude": new_mag,
                "updatedAt": datetime.now(timezone.utc).isoformat(),
            })


@firestore_fn.on_document_created(
    document="NewsletterMetadata/{docId}",
    region="us-central1",
    memory=512,
    timeout_sec=300,
)
def extractStories(
    event: firestore_fn.Event[firestore_fn.DocumentSnapshot | None],
) -> None:
    """Extract stories from a newly arrived newsletter and write to stories collection."""
    if event.data is None:
        return

    doc_id = event.params.get("docId", "")
    data = event.data.to_dict()
    sender = data.get("sender", "")

    db = firestore.client()
    sender_id = resolve_sender_id(sender, db)
    if not sender_id:
        print(f"extractStories: unknown sender '{sender}', skipping")
        return

    display_name = resolve_sender_display_name(sender, db) or extract_display_name(sender)
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    # 1. Fetch newsletter HTML body
    data_doc = db.collection("NewsletterData").document(doc_id).get()
    if not data_doc.exists:
        print(f"extractStories: no NewsletterData for {doc_id}")
        return
    body_html = data_doc.to_dict().get("body", "")
    if not body_html.strip():
        print(f"extractStories: empty body for {doc_id}")
        return

    # 2. Parse HTML into sections and inject anchors
    sections, anchored_html = parse_sections(body_html)
    if not sections:
        print(f"extractStories: no sections parsed for {doc_id}")
        return

    # 3. Write anchored HTML back to NewsletterData
    db.collection("NewsletterData").document(doc_id).update({
        "anchoredBody": anchored_html,
    })

    # 4. Load categories from Config/digestCategories
    config_doc = db.collection("Config").document("digestCategories").get()
    if config_doc.exists:
        categories = config_doc.to_dict().get("sections", DEFAULT_SECTIONS)
    else:
        categories = DEFAULT_SECTIONS

    # 5. Load prominence weights from Config/sourceProminence
    prom_doc = db.collection("Config").document("sourceProminence").get()
    if prom_doc.exists:
        prominence_weights = prom_doc.to_dict()
    else:
        prominence_weights = DEFAULT_PROMINENCE
        # Auto-seed the document
        db.collection("Config").document("sourceProminence").set(DEFAULT_PROMINENCE)

    # 6. Query existing stories for today (for deduplication)
    existing_stories = []
    existing_docs = db.collection("stories").where("date", "==", today).stream()
    for edoc in existing_docs:
        edata = edoc.to_dict()
        existing_stories.append({
            "id": edoc.id,
            "headline": edata.get("headline", ""),
        })

    # 7. Build prompt and call Gemini
    prompt = build_extraction_prompt(
        sections, sender_id, display_name, categories, existing_stories
    )

    client = genai.Client(vertexai=True, project=PROJECT_ID, location=LOCATION)
    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=STORY_EXTRACTION_SCHEMA,
            ),
        )
        parsed = json.loads(response.text)
    except Exception as e:
        print(f"extractStories: Gemini call failed for {doc_id}: {e}")
        return

    extracted = parsed.get("stories", [])
    if not extracted:
        print(f"extractStories: no stories extracted from {doc_id}")
        return

    now_iso = datetime.now(timezone.utc).isoformat()

    # 8. Count total newsletters today (for magnitude calculation)
    today_start = datetime.now(timezone.utc).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    today_end = today_start + timedelta(days=1)
    meta_count = len(list(
        db.collection("NewsletterMetadata")
        .where("newsletterDate", ">=", today_start)
        .where("newsletterDate", "<", today_end)
        .stream()
    ))

    # 9. Create or merge story documents
    source_entry = {
        "newsletterId": doc_id,
        "senderId": sender_id,
        "displayName": display_name,
    }

    for story in extracted:
        match_id = story.get("matchesExistingStoryId", "")

        story_source = {
            **source_entry,
            "sectionIndex": story.get("sectionIndex", 0),
            "positionRank": story.get("positionRank", 1),
        }

        image_urls = story.get("imageUrls", [])
        images = [{"url": url, "newsletterId": doc_id} for url in image_urls if url]

        if match_id:
            # Merge into existing story
            existing_ref = db.collection("stories").document(match_id)
            existing_doc = existing_ref.get()
            if existing_doc.exists:
                existing_data = existing_doc.to_dict()
                sources = existing_data.get("sources", [])
                # Avoid duplicate source entries
                if not any(s.get("newsletterId") == doc_id for s in sources):
                    sources.append(story_source)
                existing_images = existing_data.get("images", [])
                existing_images.extend(images)
                magnitude = calculate_magnitude(sources, meta_count, prominence_weights)
                existing_ref.update({
                    "sources": sources,
                    "images": existing_images,
                    "magnitude": magnitude,
                    "updatedAt": now_iso,
                })
                continue

        # Create new story
        story_doc_id = f"{today}_{db.collection('stories').document().id}"
        magnitude = calculate_magnitude([story_source], meta_count, prominence_weights)

        db.collection("stories").document(story_doc_id).set({
            "date": today,
            "headline": story.get("headline", ""),
            "description": story.get("description", ""),
            "categories": story.get("categories", ["Other"]),
            "magnitude": magnitude,
            "sources": [story_source],
            "images": images,
            "createdAt": now_iso,
            "updatedAt": now_iso,
        })

    # 10. Recalculate magnitude for all today's stories (total newsletter count changed)
    _recalculate_all_magnitudes_today(db, today, prominence_weights, meta_count)
