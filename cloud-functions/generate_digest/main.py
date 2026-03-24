from firebase_functions import https_fn, firestore_fn
from firebase_admin import initialize_app, firestore, messaging
from google import genai
from google.genai import types
from google.cloud.firestore_v1 import FieldFilter
import html2text
import json
from datetime import datetime, timezone, timedelta

initialize_app()

PROJECT_ID = "newsletters-c8650"
LOCATION = "us-central1"
MAX_CHARS_PER_NEWSLETTER = 32000  # ~8K tokens

DEFAULT_SECTIONS = [
    "Business & Finance", "Startups & Venture Capital", "Artificial Intelligence",
    "US Politics", "World Politics", "Healthcare", "Science", "Technology",
    "Climate & Environment", "Culture & Entertainment", "Sports", "Other"
]

# Vertex AI response schema for structured output
DIGEST_SCHEMA = {
    "type": "object",
    "properties": {
        "sections": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "title": {"type": "string"},
                    "items": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "headline": {"type": "string"},
                                "description": {"type": "string"},
                                "sources": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "newsletterId": {"type": "string"},
                                            "displayName": {"type": "string"}
                                        },
                                        "required": ["newsletterId", "displayName"]
                                    }
                                }
                            },
                            "required": ["headline", "description", "sources"]
                        }
                    }
                },
                "required": ["title", "items"]
            }
        }
    },
    "required": ["sections"]
}


def extract_display_name(sender: str) -> str:
    """Extract display name from 'Name <email@domain>' format."""
    if "<" in sender:
        return sender.split("<")[0].strip().strip('"')
    return sender.strip()



def build_prompt(blocks: list[str], sections: list[str]) -> str:
    sections_str = ", ".join(sections)
    newsletters_content = "\n\n---\n\n".join(blocks)
    return f"""You are summarising today's newsletters into a digest.

NEWSLETTERS:
{newsletters_content}

INSTRUCTIONS:
- Categorise stories into these sections: {sections_str}
- A story may appear in multiple sections if relevant
- Deduplicate: if multiple newsletters cover the same story, merge them into ONE item and list all sources
- Each source must include the newsletterId (the ID from the label) and displayName (the name from the label)
- The label format is [newsletterId|Display Name]
- Use "Other" for stories that don't fit the named sections
- Omit sections with no stories
- Keep descriptions to 1-2 sentences
- Ignore any advertising, sponsored content, promotional sections, or calls to action

Output valid JSON matching the provided schema."""


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

    # Step 1: Read user's enabledNewsletters (sender emails)
    prefs_ref = (db.collection("users").document(uid)
                   .collection("settings").document("preferences"))
    prefs_doc = prefs_ref.get()

    if not prefs_doc.exists:
        return _write_empty_and_return(db, uid, today, now_iso)

    enabled_emails = set(prefs_doc.to_dict().get("enabledNewsletters", []))
    if not enabled_emails:
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
        sender = data.get("sender", "").lower()
        if any(email.lower() in sender for email in enabled_emails):
            newsletters.append({
                "id": doc.id,
                "sender": data.get("sender", "")
            })

    if not newsletters:
        return _write_empty_and_return(db, uid, today, now_iso)

    # Step 3: Fetch NewsletterData bodies, strip HTML
    h = html2text.HTML2Text()
    h.ignore_links = True
    h.ignore_images = True

    blocks = []
    for nl in newsletters:
        data_doc = db.collection("NewsletterData").document(nl["id"]).get()
        if data_doc.exists:
            body_html = data_doc.to_dict().get("body", "")
            body_text = h.handle(body_html)[:MAX_CHARS_PER_NEWSLETTER]
            display_name = extract_display_name(nl["sender"])
            blocks.append(f"[{nl['id']}|{display_name}]\n{body_text}")

    if not blocks:
        return _write_empty_and_return(db, uid, today, now_iso)

    # Step 4: Load sections from Firestore config, seeding if absent
    config_ref = db.collection("Config").document("digestCategories")
    config_doc = config_ref.get()
    if config_doc.exists:
        sections = config_doc.to_dict().get("sections", DEFAULT_SECTIONS)
    else:
        sections = DEFAULT_SECTIONS
        config_ref.set({"sections": DEFAULT_SECTIONS})

    client = genai.Client(vertexai=True, project=PROJECT_ID, location=LOCATION)
    prompt = build_prompt(blocks, sections)

    response = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=prompt,
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            response_schema=DIGEST_SCHEMA
        )
    )

    # Step 5: Parse, validate, write to Firestore, and return
    parsed = json.loads(response.text)
    sections_data = parsed.get("sections", [])

    doc_data = {
        "generatedAt": now_iso,
        "newsletterCount": len(newsletters),
        "newsletterIds": [nl["id"] for nl in newsletters],
        "sections": sections_data
    }

    (db.collection("users").document(uid)
       .collection("digests").document(today)
       .set(doc_data))

    return doc_data


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
    sender_email = _extract_email(sender)

    if not sender_email:
        return

    db = firestore.client()

    # Find users with notifications enabled for this sender email
    try:
        prefs_query = (db.collection_group("settings")
                         .where(filter=FieldFilter("notificationNewsletters", "array-contains", sender_email)))
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
