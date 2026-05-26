import pytest
import requests


def _is_oidc(client_options):
    return "oidc_token" in client_options


class TestSystemLogs:
    def test_get(self, client, client_options):
        if _is_oidc(client_options):
            with pytest.raises(requests.HTTPError) as exc:
                client.get_system_logs()
            assert exc.value.response.status_code == 403
        else:
            resp = client.get_system_logs()
            assert resp.status_code in (200, 204)

    def test_with_timestamps(self, client, client_options):
        if _is_oidc(client_options):
            with pytest.raises(requests.HTTPError) as exc:
                client.get_system_logs(timestamps=True)
            assert exc.value.response.status_code == 403
        else:
            resp = client.get_system_logs(timestamps=True)
            assert resp.status_code in (200, 204)

    def test_json_output(self, client, client_options):
        if _is_oidc(client_options):
            with pytest.raises(requests.HTTPError) as exc:
                client.get_system_logs()
            assert exc.value.response.status_code == 403
        else:
            resp = client.get_system_logs()
            assert resp.status_code in (200, 204)
            assert len(resp.text) > 0
