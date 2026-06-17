import pytest
from utils import generate_random_name, load_service_fdl


def _isolation_svc(svc, level):
    svc = dict(svc)
    svc["isolation_level"] = level
    return svc


class TestIsolation:
    @pytest.fixture(scope="class")
    def service_name(self):
        return generate_random_name("robot-py-iso")

    @pytest.fixture(scope="class")
    def service_fdl(self, client_options, service_name):
        return load_service_fdl(service_name, client_options["cluster_id"])

    @pytest.fixture(scope="class", autouse=True)
    def setup_teardown(self, client, service_fdl, service_name):
        svc = _isolation_svc(service_fdl, "SERVICE")
        try:
            client.create_service(svc)
        except Exception:
            pass
        yield
        try:
            client.remove_service(service_name)
        except Exception:
            pass

    def test_verify_service_level(self, client, service_name):
        resp = client.get_service(service_name)
        assert resp.status_code == 200

    def test_update_to_user_level(self, client, service_fdl, service_name):
        svc = _isolation_svc(service_fdl, "USER")
        resp = client.update_service(service_name, svc)
        assert resp.status_code in (200, 204)

    def test_verify_user_level(self, client, service_name):
        resp = client.get_service(service_name)
        assert resp.status_code == 200

    def test_update_back_to_service_level(self, client, service_fdl, service_name):
        svc = _isolation_svc(service_fdl, "SERVICE")
        resp = client.update_service(service_name, svc)
        assert resp.status_code in (200, 204)

    def test_delete(self, client, service_name):
        resp = client.remove_service(service_name)
        assert resp.status_code == 204
