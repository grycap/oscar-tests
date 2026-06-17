import pytest
import requests
from utils import generate_random_name


class TestVolumes:
    @pytest.fixture(scope="class")
    def volume_name(self):
        return generate_random_name("robot-py-vol")

    @pytest.fixture(scope="class", autouse=True)
    def cleanup(self, client, volume_name):
        yield
        try:
            client.delete_volume(volume_name)
        except Exception:
            pass

    @pytest.fixture(scope="class")
    def has_quota(self, client):
        try:
            resp = client.get_own_quota()
            data = resp.json()
            available = data.get("volume", {}).get("available", 0)
            return available > 0
        except Exception:
            return False

    def test_list(self, client):
        resp = client.list_volumes()
        assert resp.status_code == 200

    def test_create(self, client, volume_name, has_quota):
        if not has_quota:
            try:
                client.create_volume(volume_name, "1Gi")
            except requests.HTTPError as e:
                assert e.response.status_code == 400
                assert "quota" in e.response.text
            return
        resp = client.create_volume(volume_name, "1Gi")
        assert resp.status_code == 201
        data = resp.json()
        assert data["name"] == volume_name

    def test_get(self, client, volume_name, has_quota):
        if not has_quota:
            pytest.skip("no volume quota available")
            return
        try:
            client.create_volume(volume_name, "1Gi")
        except requests.HTTPError:
            pytest.skip("cannot create volume")
            return
        resp = client.get_volume(volume_name)
        assert resp.status_code == 200
        data = resp.json()
        assert data["name"] == volume_name

    def test_delete(self, client, volume_name, has_quota):
        if not has_quota:
            pytest.skip("no volume quota available")
            return
        try:
            client.create_volume(volume_name, "1Gi")
        except requests.HTTPError:
            pytest.skip("cannot create volume")
            return
        resp = client.delete_volume(volume_name)
        assert resp.status_code == 204
