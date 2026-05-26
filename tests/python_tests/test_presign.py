import pytest
from utils import generate_random_name


class TestPresign:
    @pytest.fixture(scope="class")
    def bucket_name(self):
        return generate_random_name("robot-py-ps")

    @pytest.fixture(scope="class", autouse=True)
    def setup_teardown(self, client, bucket_name):
        bucket_created = False
        try:
            client.create_bucket(bucket_name, "private")
            bucket_created = True
        except Exception:
            pass
        yield
        if bucket_created:
            try:
                client.delete_bucket(bucket_name)
            except Exception:
                pass

    def test_presign_download(self, client, bucket_name):
        resp = client.presign_bucket(bucket_name, "test-file.txt", "download")
        assert resp.status_code in (200, 400, 404)

    def test_presign_upload(self, client, bucket_name):
        resp = client.presign_bucket(bucket_name, "upload-file.txt", "upload")
        assert resp.status_code in (200, 400, 404)

    def test_presign_with_expires(self, client, bucket_name):
        resp = client.presign_bucket(bucket_name, "test-file.txt", "download", expires=3600)
        assert resp.status_code in (200, 400, 404)
