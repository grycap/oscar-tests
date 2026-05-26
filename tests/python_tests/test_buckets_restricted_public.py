import pytest
from utils import generate_random_name


class TestBucketsRestricted:
    @pytest.fixture(scope="class")
    def bucket_name(self):
        return generate_random_name("robot-py-bkt-r")

    @pytest.fixture(scope="class", autouse=True)
    def setup_teardown(self, client, bucket_name):
        yield
        try:
            client.delete_bucket(bucket_name)
        except Exception:
            pass

    def test_create_restricted(self, client, bucket_name, other_user_sub):
        resp = client.create_bucket(bucket_name, "restricted", [other_user_sub])
        assert resp.status_code == 201

    def test_list_shows_restricted(self, client, bucket_name):
        resp = client.list_buckets()
        assert resp.status_code == 200
        buckets = resp.json()
        match = [b for b in buckets if b["bucket_name"] == bucket_name]
        assert len(match) == 1
        assert match[0]["visibility"] == "restricted"

    def test_delete_restricted(self, client, bucket_name):
        resp = client.delete_bucket(bucket_name)
        assert resp.status_code == 204


class TestBucketsPublic:
    @pytest.fixture(scope="class")
    def bucket_name(self):
        return generate_random_name("robot-py-bkt-p")

    @pytest.fixture(scope="class", autouse=True)
    def setup_teardown(self, client, bucket_name):
        yield
        try:
            client.delete_bucket(bucket_name)
        except Exception:
            pass

    def test_create_public(self, client, bucket_name):
        resp = client.create_bucket(bucket_name, "public")
        assert resp.status_code == 201

    def test_list_shows_public(self, client, bucket_name):
        resp = client.list_buckets()
        assert resp.status_code == 200
        buckets = resp.json()
        match = [b for b in buckets if b["bucket_name"] == bucket_name]
        assert len(match) == 1
        assert match[0]["visibility"] == "public"

    def test_delete_public(self, client, bucket_name):
        resp = client.delete_bucket(bucket_name)
        assert resp.status_code == 204
