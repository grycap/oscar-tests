import pytest
from utils import generate_random_name, load_service_fdl


class TestMount:
    @pytest.fixture(scope="class")
    def service_name(self):
        return generate_random_name("robot-py-mnt")

    @pytest.fixture(scope="class")
    def mount_bucket(self):
        return generate_random_name("robot-py-mnt-bkt")

    @pytest.fixture(scope="class")
    def service_fdl(self, client_options, service_name):
        return load_service_fdl(service_name, client_options["cluster_id"])

    @pytest.fixture(scope="class", autouse=True)
    def setup_teardown(self, client, service_fdl, service_name, mount_bucket):
        bucket_created = False
        try:
            client.create_bucket(mount_bucket, "private")
            bucket_created = True
        except Exception:
            pass
        try:
            client.create_service(service_fdl)
        except Exception:
            pass
        yield
        try:
            client.remove_service(service_name)
        except Exception:
            pass
        if bucket_created:
            try:
                client.delete_bucket(mount_bucket)
            except Exception:
                pass

    def test_verify_service_and_mount_bucket_exist(self, client, service_name, mount_bucket):
        resp = client.get_service(service_name)
        assert resp.status_code == 200
        resp = client.list_buckets()
        assert resp.status_code == 200
        buckets = resp.json()
        names = [b["bucket_name"] for b in buckets]
        assert mount_bucket in names

    def test_delete_service_mount_bucket_persists(self, client, service_name, mount_bucket):
        resp = client.remove_service(service_name)
        assert resp.status_code == 204
        resp = client.list_buckets()
        buckets = resp.json()
        names = [b["bucket_name"] for b in buckets]
        assert mount_bucket in names
