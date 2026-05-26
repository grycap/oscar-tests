import pytest
from utils import generate_random_name, load_service_fdl


class TestServices:
    @pytest.fixture(scope="class")
    def service_name(self):
        return generate_random_name("robot-py-svc")

    @pytest.fixture(scope="class")
    def service_fdl(self, client_options, service_name):
        return load_service_fdl(service_name, client_options["cluster_id"])

    @pytest.fixture(scope="class", autouse=True)
    def setup_teardown(self, client, service_fdl, service_name):
        try:
            client.create_service(service_fdl)
        except Exception:
            pass
        yield
        try:
            client.remove_service(service_name)
        except Exception:
            pass

    def test_list(self, client):
        resp = client.list_services()
        assert resp.status_code == 200

    def test_get(self, client, service_name):
        resp = client.get_service(service_name)
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("name") == service_name

    def test_delete(self, client, service_name):
        resp = client.remove_service(service_name)
        assert resp.status_code == 204
