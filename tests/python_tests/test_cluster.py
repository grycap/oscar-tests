import pytest


class TestCluster:
    def test_installed(self):
        import subprocess
        result = subprocess.run(["oscar-cli"], capture_output=True, text=True)
        assert result.returncode == 0

    def test_info(self, client):
        resp = client.get_cluster_info()
        assert resp.status_code == 200
        data = resp.json()
        assert "version" in data

    def test_config(self, client):
        resp = client.get_cluster_config()
        assert resp.status_code == 200

    def test_status(self, client):
        resp = client.get_cluster_status()
        assert resp.status_code == 200

    def test_health(self, client):
        resp = client.health_check()
        assert resp.status_code == 200

    def test_metrics_summary(self, client):
        resp = client.get_metrics_summary()
        assert resp.status_code == 200

    def test_metrics_breakdown(self, client):
        resp = client.get_metrics_breakdown()
        assert resp.status_code == 200

    def test_own_quota(self, client):
        resp = client.get_own_quota()
        assert resp.status_code == 200
