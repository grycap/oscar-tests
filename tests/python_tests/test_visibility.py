import pytest
from utils import generate_random_name, load_service_fdl


def _visibility_svc(svc, visibility, allowed_users=None):
    svc = dict(svc)
    svc["visibility"] = visibility
    if allowed_users:
        svc["allowed_users"] = allowed_users
    return svc


class TestVisibility:
    @pytest.fixture(scope="class")
    def service_name(self):
        return generate_random_name("robot-py-vis")

    @pytest.fixture(scope="class")
    def service_fdl(self, client_options, service_name):
        return load_service_fdl(service_name, client_options["cluster_id"])

    @pytest.fixture(scope="class", autouse=True)
    def setup_teardown(self, client, service_fdl, service_name):
        svc = _visibility_svc(service_fdl, "private")
        try:
            client.create_service(svc)
        except Exception:
            pass
        yield
        try:
            client.remove_service(service_name)
        except Exception:
            pass

    def test_verify_private(self, client, service_name):
        resp = client.get_service(service_name)
        assert resp.status_code == 200

    def test_update_to_public(self, client, service_fdl, service_name):
        svc = _visibility_svc(service_fdl, "public")
        resp = client.update_service(service_name, svc)
        assert resp.status_code in (200, 204)

    def test_update_to_restricted(self, client, service_fdl, service_name, other_user_sub):
        svc = _visibility_svc(service_fdl, "restricted", [other_user_sub])
        resp = client.update_service(service_name, svc)
        assert resp.status_code in (200, 204)

    def test_update_back_to_private(self, client, service_fdl, service_name):
        svc = _visibility_svc(service_fdl, "private")
        resp = client.update_service(service_name, svc)
        assert resp.status_code in (200, 204)

    def test_delete(self, client, service_name):
        resp = client.remove_service(service_name)
        assert resp.status_code == 204
