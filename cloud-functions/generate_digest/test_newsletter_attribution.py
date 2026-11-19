import unittest
from unittest.mock import Mock

from newsletter_attribution import NewsletterSources, load_newsletter_sources


SENDER = "Andrew Ross Sorkin <nytdirect@nytimes.com>"
CONFIG = {
    "nytMorning": {"displayName": "The Morning", "emails": ["nytdirect@nytimes.com"]},
    "nytDealBook": {"displayName": "DealBook", "emails": []},
    "morningBrew": {"displayName": "Morning Brew", "emails": ["crew@morningbrew.com"]},
}


class NewsletterAttributionTest(unittest.TestCase):
    def setUp(self):
        self.sources = NewsletterSources(CONFIG)

    def test_tagged_issue_takes_precedence_over_shared_sender(self):
        source = self.sources.resolve({"sender": SENDER, "newsletterSourceId": "nytDealBook"})
        self.assertEqual((source.id, source.display_name), ("nytDealBook", "DealBook"))

    def test_untagged_shared_sender_keeps_legacy_match(self):
        self.assertEqual(self.sources.resolve({"sender": SENDER}).id, "nytMorning")

    def test_unknown_id_does_not_take_another_edition(self):
        self.assertIsNone(self.sources.resolve({"sender": SENDER, "newsletterSourceId": "unknown"}))

    def test_malformed_explicit_id_does_not_crash(self):
        self.assertIsNone(self.sources.resolve({"sender": SENDER, "newsletterSourceId": ["nytDealBook"]}))

    def test_unrelated_sender_is_unchanged(self):
        self.assertEqual(self.sources.resolve({"sender": "Crew@MorningBrew.com"}).id, "morningBrew")
        self.assertIsNone(self.sources.resolve({"sender": "other@example.com"}))

    def test_config_read_once_per_snapshot_and_refreshed_next_load(self):
        db = Mock()
        ref = db.collection.return_value.document.return_value
        before = {key: value for key, value in CONFIG.items() if key != "nytDealBook"}
        ref.get.side_effect = [
            Mock(exists=True, to_dict=Mock(return_value=before)),
            Mock(exists=True, to_dict=Mock(return_value=CONFIG)),
        ]
        event = {"sender": SENDER, "newsletterSourceId": "nytDealBook"}
        sources = load_newsletter_sources(db)
        self.assertIsNone(sources.resolve(event))
        self.assertIsNone(sources.resolve(event))
        ref.get.assert_called_once()
        self.assertEqual(load_newsletter_sources(db).resolve(event).id, "nytDealBook")
        self.assertEqual(ref.get.call_count, 2)
        db.collection.assert_called_with("Config")
        db.collection.return_value.document.assert_called_with("newsletters")


if __name__ == "__main__":
    unittest.main()
