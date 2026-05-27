import os
import yaml
import random
import string
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
DATA_DIR = PROJECT_ROOT / "data"


def generate_random_name(prefix, length=8):
    suffix = "".join(random.choices(string.ascii_lowercase + string.digits, k=length))
    return f"{prefix}-{suffix}"


def load_service_fdl(service_name, cluster_id="robot-py", vo="/oscar-test"):
    with open(DATA_DIR / "00-cowsay.yaml") as f:
        content = yaml.safe_load(f)
    svc = content["functions"]["oscar"][0][cluster_id]
    svc["name"] = service_name
    svc["vo"] = vo
    script_path = DATA_DIR / svc.get("script", "00-cowsay-script.sh")
    if script_path.exists():
        svc["script"] = script_path.read_text()
    for inp in svc.get("input", []):
        inp["path"] = inp["path"].replace("robot-test-cowsay", service_name)
    for out in svc.get("output", []):
        out["path"] = out["path"].replace("robot-test-cowsay", service_name)
    return svc
