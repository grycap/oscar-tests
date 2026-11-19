printf '%s' '__PROBE_B64__' | base64 -d > /tmp/network_policy_probe.py
exec python3 /tmp/network_policy_probe.py
