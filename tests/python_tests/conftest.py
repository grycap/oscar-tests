import os
import sys
import yaml
import json
import pytest
import requests
from pathlib import Path


# Ensure this directory is on sys.path so utils.py is importable
sys.path.insert(0, str(Path(__file__).parent.resolve()))

from utils import generate_random_name, load_service_fdl

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
DATA_DIR = PROJECT_ROOT / "data"
VARIABLES_DIR = PROJECT_ROOT / "variables"


def load_yaml_env(path):
    with open(path) as f:
        return yaml.safe_load(f)


def get_oidc_tokens(aai_url, client_id, username, password, scope):
    url = f"{aai_url}/protocol/openid-connect/token"
    data = {
        "grant_type": "password",
        "username": username,
        "password": password,
        "client_id": client_id,
        "scope": scope,
    }
    resp = requests.post(url, data=data, timeout=30)
    resp.raise_for_status()
    return resp.json()


def get_token_endpoint(aai_url):
    return f"{aai_url}/protocol/openid-connect/token"


def build_oidc_options(auth_cfg, cluster_cfg):
    scope = auth_cfg.get("SCOPE", "openid email profile")
    scope = scope.replace("%20", " ")
    tokens = get_oidc_tokens(
        auth_cfg["AAI_URL"],
        auth_cfg["CLIENT_ID"],
        auth_cfg["KEYCLOAK_USERNAME"],
        auth_cfg["KEYCLOAK_PASSWORD"],
        scope,
    )
    sub = _get_user_sub(tokens["access_token"], auth_cfg["AAI_URL"])
    return {
        "cluster_id": cluster_cfg.get("CLUSTER_NAME", "robot-oscar-cluster"),
        "endpoint": cluster_cfg["OSCAR_ENDPOINT"],
        "oidc_token": tokens["access_token"],
        "refresh_token": tokens["refresh_token"],
        "token_endpoint": get_token_endpoint(auth_cfg["AAI_URL"]),
        "client_id": auth_cfg["CLIENT_ID"],
        "scopes": scope.split(),
        "ssl": cluster_cfg.get("SSL_VERIFY", True),
        "user_sub": sub,
    }


def build_basic_auth_options(auth_cfg, cluster_cfg):
    basic_user = cluster_cfg.get("BASIC_USER", "")
    user, password = _decode_basic_auth(basic_user)
    return {
        "cluster_id": cluster_cfg.get("CLUSTER_NAME", "robot-oscar-cluster"),
        "endpoint": cluster_cfg["OSCAR_ENDPOINT"],
        "user": user,
        "password": password,
        "ssl": cluster_cfg.get("SSL_VERIFY", True),
    }


def _get_user_sub(access_token, aai_url):
    url = f"{aai_url}/protocol/openid-connect/userinfo"
    headers = {"Authorization": f"Bearer {access_token}"}
    resp = requests.get(url, headers=headers, timeout=30)
    resp.raise_for_status()
    return resp.json().get("sub", "")


def _decode_basic_auth(b64_str):
    import base64
    decoded = base64.b64decode(b64_str).decode("utf-8")
    user, password = decoded.split(":", 1)
    return user, password


@pytest.fixture(scope="session")
def auth_config():
    auth_goal = os.environ.get("OSCAR_TEST_AUTH_GOAL", "auth-keycloak")
    auth_slug = auth_goal.replace("auth-", "")
    paths = [
        VARIABLES_DIR / f".env-{auth_slug}.yaml",
        VARIABLES_DIR / f".env-auth-{auth_slug}.yaml",
    ]
    for p in paths:
        if p.exists():
            return load_yaml_env(p)
    raise FileNotFoundError(f"No auth config found for {auth_goal}")


@pytest.fixture(scope="session")
def cluster_config():
    cluster_goal = os.environ.get("OSCAR_TEST_CLUSTER_GOAL", "iisas")
    cluster_slug = cluster_goal.replace("cluster-", "")
    paths = [
        VARIABLES_DIR / f".env-{cluster_slug}.yaml",
        VARIABLES_DIR / f".env-cluster-{cluster_slug}.yaml",
    ]
    for p in paths:
        if p.exists():
            return load_yaml_env(p)
    raise FileNotFoundError(f"No cluster config found for {cluster_goal}")


@pytest.fixture(scope="session")
def client_options(auth_config, cluster_config):
    if "AAI_URL" in auth_config:
        return build_oidc_options(auth_config, cluster_config)
    raise ValueError("Unsupported auth type")


@pytest.fixture(scope="session")
def client(client_options):
    from oscar_python.client import Client
    c = Client(client_options)
    return c


@pytest.fixture
def service_name():
    return generate_random_name("robot-py-svc")


@pytest.fixture
def bucket_name():
    return generate_random_name("robot-py-bkt")


@pytest.fixture
def volume_name():
    return generate_random_name("robot-py-vol")


@pytest.fixture
def service_fdl(service_name, client_options):
    return load_service_fdl(service_name, client_options["cluster_id"])


@pytest.fixture
def user_sub(client_options):
    return client_options.get("user_sub", "")


@pytest.fixture
def other_user_sub(auth_config):
    scope = auth_config.get("SCOPE", "openid email profile").replace("%20", " ")
    tokens = get_oidc_tokens(
        auth_config["AAI_URL"],
        auth_config["CLIENT_ID"],
        auth_config["KEYCLOAK_USERNAME_AUX"],
        auth_config["KEYCLOAK_PASSWORD_AUX"],
        scope,
    )
    sub = _get_user_sub(tokens["access_token"], auth_config["AAI_URL"])
    return sub
