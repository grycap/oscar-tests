import pytest
from utils import generate_random_name


class TestQuotas:
    def test_get_own(self, client):
        resp = client.get_own_quota()
        assert resp.status_code == 200

    def test_get_service_metrics(self, client, service_fdl, service_name):
        try:
            client.create_service(service_fdl)
        except Exception:
            pass
        try:
            resp = client.get_service_metrics(service_name)
            assert resp.status_code == 200
        finally:
            try:
                client.remove_service(service_name)
            except Exception:
                pass
