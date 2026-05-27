import time
import pytest
from utils import generate_random_name, load_service_fdl


class TestDeployment:
    @pytest.fixture(scope="class")
    def service_name(self):
        return generate_random_name("robot-py-dep")

    @pytest.fixture(scope="class")
    def service_fdl(self, client_options, service_name):
        return load_service_fdl(service_name, client_options["cluster_id"])

    @pytest.fixture(scope="class", autouse=True)
    def setup_teardown(self, client, service_fdl, service_name):
        try:
            client.create_service(service_fdl)
        except Exception:
            pass
        else:
            time.sleep(10)
        yield
        try:
            client.remove_service(service_name)
        except Exception:
            pass

    def test_deployment_status(self, client, service_name):
        resp = client.get_deployment_status(service_name)
        assert resp.status_code == 200

    def test_deployment_logs(self, client, service_name):
        resp = client.get_deployment_logs(service_name)
        assert resp.status_code == 200

    def test_delete(self, client, service_name):
        resp = client.remove_service(service_name)
        assert resp.status_code == 204
