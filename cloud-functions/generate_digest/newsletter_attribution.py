"""Resolve newsletter attribution from a single snapshot of Config/newsletters."""

from dataclasses import dataclass


@dataclass(frozen=True)
class NewsletterSource:
    id: str
    display_name: str


def _extract_email(sender: str) -> str:
    if "<" in sender and ">" in sender:
        return sender.split("<")[1].rstrip(">").strip().lower()
    if "@" in sender:
        return sender.strip().lower()
    return ""


class NewsletterSources:
    def __init__(self, config: dict):
        self._by_id = {}
        self._by_email = {}
        for source_id, info in config.items():
            if not isinstance(info, dict):
                continue
            name = info.get("displayName")
            source = NewsletterSource(source_id, name if isinstance(name, str) and name else source_id)
            self._by_id[source_id] = source
            emails = info.get("emails")
            if isinstance(emails, list):
                for email in emails:
                    if isinstance(email, str) and email.strip():
                        self._by_email[email.strip().lower()] = source

    def resolve(self, metadata: dict) -> NewsletterSource | None:
        source_id = metadata.get("newsletterSourceId")
        if source_id is not None and source_id != "":
            # A tagged issue must not silently become another edition that
            # happens to share its sender. Unknown/invalid explicit IDs fail closed.
            return self._by_id.get(source_id) if isinstance(source_id, str) else None

        sender = metadata.get("sender")
        return self._by_email.get(_extract_email(sender)) if isinstance(sender, str) else None


def load_newsletter_sources(db) -> NewsletterSources:
    # Snapshot once per invocation so new config is visible on warm instances,
    # without a Firestore read for every issue in a digest.
    doc = db.collection("Config").document("newsletters").get()
    return NewsletterSources((doc.to_dict() or {}) if doc.exists else {})
