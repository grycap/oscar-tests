import pytest
from utils import generate_random_name


class TestBuckets:
    @pytest.fixture(scope="class")
    def bucket_name(self):
        return generate_random_name("robot-py-bkt")

    @pytest.fixture(scope="class", autouse=True)
    def setup_teardown(self, client, bucket_name):
        yield
        try:
            client.delete_bucket(bucket_name)
        except Exception:
            pass

    def test_create_private(self, client, bucket_name):
        resp = client.create_bucket(bucket_name, "private")
        assert resp.status_code == 201

    def test_list_shows_private(self, client, bucket_name):
        resp = client.list_buckets()
        assert resp.status_code == 200
        buckets = resp.json()
        names = [b["bucket_name"] for b in buckets]
        assert bucket_name in names

    def test_update_private_to_public(self, client, bucket_name):
        resp = client.update_bucket(bucket_name, "public")
        assert resp.status_code in (200, 204)

    def test_list_shows_public(self, client, bucket_name):
        resp = client.list_buckets()
        assert resp.status_code == 200
        buckets = resp.json()
        match = [b for b in buckets if b["bucket_name"] == bucket_name]
        assert len(match) == 1
        assert match[0]["visibility"] == "public"

    def test_update_public_to_private(self, client, bucket_name):
        resp = client.update_bucket(bucket_name, "private")
        assert resp.status_code in (200, 204)

    def test_list_shows_private_again(self, client, bucket_name):
        resp = client.list_buckets()
        assert resp.status_code == 200
        buckets = resp.json()
        match = [b for b in buckets if b["bucket_name"] == bucket_name]
        assert len(match) == 1
        assert match[0]["visibility"] == "private"

    def test_delete_private(self, client, bucket_name):
        resp = client.delete_bucket(bucket_name)
        assert resp.status_code == 204

    def test_list_after_all_deletions(self, client, bucket_name):
        resp = client.list_buckets()
        assert resp.status_code == 200
        buckets = resp.json()
        names = [b["bucket_name"] for b in buckets]
        assert bucket_name not in names
