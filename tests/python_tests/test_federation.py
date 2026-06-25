import random
import string

import pytest
from utils import generate_random_name


def _make_simple_service_body(name, cluster_id):
    return {
        "name": name,
        "cluster_id": cluster_id,
        "cpu": "0.5",
        "memory": "256Mi",
        "image": "ubuntu",
        "script": "#!/bin/bash\nsleep 10\n",
        "allowed_users": [],
        "visibility": "private",
    }


def _make_federation_service_body(name, cluster_id, topology):
    return {
        "name": name,
        "cluster_id": cluster_id,
        "cpu": "0.5",
        "memory": "256Mi",
        "image": "ubuntu",
        "script": "#!/bin/bash\nsleep 10\n",
        "allowed_users": [],
        "visibility": "private",
        "environment": {"secrets": {"refresh_token": "dummy-token"}},
        "federation": {"topology": topology, "delegation": "random", "members": []},
    }


def _get_clusters(endpoint, ssl_verify):
    entry = {"endpoint": endpoint, "ssl_verify": ssl_verify}
    return {
        "oscar-primary": dict(entry),
        "oscar-jetson": dict(entry),
        "oscar-graspi": dict(entry),
    }


class TestFederation:
    @pytest.fixture(scope="class")
    def names(self):
        suffix = "".join(random.choices(string.ascii_lowercase + string.digits, k=8))
        return {
            "non_fed": f"robot-py-fed-non-{suffix}",
            "worker1": f"robot-py-fed-w1-{suffix}",
            "worker2": f"robot-py-fed-w2-{suffix}",
            "main_star": f"robot-py-fed-main-{suffix}",
            "main_mesh": f"robot-py-fed-mesh-{suffix}",
            "cluster_a": "oscar-jetson",
            "cluster_b": "oscar-graspi",
            "cluster_main": "oscar-primary",
        }

    @pytest.fixture(scope="class", autouse=True)
    def setup_teardown(self, client, client_options, names):
        body = _make_simple_service_body(names["non_fed"], names["cluster_main"])
        client.create_service(body)
        body = _make_simple_service_body(names["worker1"], names["cluster_a"])
        client.create_service(body)
        body = _make_simple_service_body(names["worker2"], names["cluster_b"])
        client.create_service(body)

        yield

        for key in ("main_star", "main_mesh", "worker2", "worker1", "non_fed"):
            try:
                client.remove_service(names[key])
            except Exception:
                pass

    # ---------------------------------------------------------------
    # Star topology
    # ---------------------------------------------------------------

    def test_get_federation_non_federated(self, client, names):
        resp = client.get_federation(names["non_fed"])
        assert resp.status_code == 200
        data = resp.json()
        assert data["topology"] == "none"
        assert data["members"] is None

    def test_create_star_federation_service(self, client, names):
        body = _make_federation_service_body(names["main_star"], names["cluster_main"], "star")
        resp = client.create_service(body)
        assert resp.status_code == 201

    def test_get_federation_star_empty(self, client, names):
        resp = client.get_federation(names["main_star"])
        assert resp.status_code == 200
        data = resp.json()
        assert data["topology"] == "star"
        assert data["members"] is None

    def test_add_federation_members(self, client, client_options, names):
        clusters = _get_clusters(client_options["endpoint"], client_options["ssl"])
        members = [
            {"type": "oscar", "cluster_id": names["cluster_a"], "service_name": names["worker1"], "priority": 0},
            {"type": "oscar", "cluster_id": names["cluster_b"], "service_name": names["worker2"], "priority": 1},
        ]
        resp = client.add_federation_members(names["main_star"], members, clusters)
        assert resp.status_code == 200

    def test_get_federation_with_members(self, client, names):
        resp = client.get_federation(names["main_star"])
        assert resp.status_code == 200
        data = resp.json()
        assert data["topology"] == "star"
        member_names = [m["service_name"] for m in data["members"]]
        assert names["worker1"] in member_names
        assert names["worker2"] in member_names

    def test_update_federation_priority(self, client, client_options, names):
        members = [{"type": "oscar", "cluster_id": names["cluster_a"], "service_name": names["worker1"]}]
        update = [{"type": "oscar", "cluster_id": names["cluster_a"], "service_name": names["worker1"], "priority": 10}]
        resp = client.update_federation_members(names["main_star"], members, update)
        assert resp.status_code == 200

    def test_get_federation_after_update(self, client, names):
        resp = client.get_federation(names["main_star"])
        assert resp.status_code == 200
        data = resp.json()
        priorities = {m["service_name"]: m["priority"] for m in data["members"]}
        assert priorities[names["worker1"]] == 10
        assert priorities[names["worker2"]] == 1

    def test_remove_federation_member(self, client, names):
        members = [{"type": "oscar", "cluster_id": names["cluster_a"], "service_name": names["worker1"]}]
        resp = client.remove_federation_members(names["main_star"], members, delete=False)
        assert resp.status_code == 200

    def test_get_federation_after_removal(self, client, names):
        resp = client.get_federation(names["main_star"])
        assert resp.status_code == 200
        data = resp.json()
        member_names = [m["service_name"] for m in (data["members"] or [])]
        assert names["worker1"] not in member_names
        assert names["worker2"] in member_names

    def test_teardown_star_service(self, client, names):
        resp = client.remove_service(names["main_star"])
        assert resp.status_code in (200, 204)

    # ---------------------------------------------------------------
    # Mesh topology
    # ---------------------------------------------------------------

    def test_create_mesh_federation_service(self, client, names):
        body = _make_federation_service_body(names["main_mesh"], names["cluster_main"], "mesh")
        resp = client.create_service(body)
        assert resp.status_code == 201

    def test_get_federation_mesh_empty(self, client, names):
        resp = client.get_federation(names["main_mesh"])
        assert resp.status_code == 200
        data = resp.json()
        assert data["topology"] == "mesh"
        assert data["members"] is None

    def test_add_member_to_mesh(self, client, client_options, names):
        clusters = _get_clusters(client_options["endpoint"], client_options["ssl"])
        members = [{"type": "oscar", "cluster_id": names["cluster_b"], "service_name": names["worker2"], "priority": 1}]
        resp = client.add_federation_members(names["main_mesh"], members, clusters)
        assert resp.status_code == 200

    def test_get_mesh_with_members(self, client, names):
        resp = client.get_federation(names["main_mesh"])
        assert resp.status_code == 200
        data = resp.json()
        member_names = [m["service_name"] for m in data["members"]]
        assert names["worker2"] in member_names

    def test_remove_mesh_federation_member(self, client, names):
        members = [{"type": "oscar", "cluster_id": names["cluster_b"], "service_name": names["worker2"]}]
        resp = client.remove_federation_members(names["main_mesh"], members, delete=False)
        assert resp.status_code == 200

    def test_get_mesh_after_removal(self, client, names):
        resp = client.get_federation(names["main_mesh"])
        assert resp.status_code == 200
        data = resp.json()
        member_names = [m["service_name"] for m in (data["members"] or [])]
        assert names["worker2"] not in member_names
