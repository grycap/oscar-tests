#!/usr/bin/env python3
"""HTTP probe used by the namespace network-isolation Robot test."""
import os
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import urlopen

TARGET_URL = os.environ["NETWORK_POLICY_TARGET_URL"]


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            socket.getaddrinfo(urlsplit(TARGET_URL).hostname, None)
        except socket.gaierror as exc:
            result = f"DNS_ERROR:{exc}"
        else:
            try:
                with urlopen(TARGET_URL, timeout=5) as response:
                    body = response.read().decode("utf-8", errors="replace")
                    result = f"CONNECTED:{response.status}:{body}"
            except HTTPError as exc:
                result = f"CONNECTED:{exc.code}"
            except (TimeoutError, socket.timeout):
                result = "BLOCKED:timeout"
            except URLError as exc:
                reason = exc.reason
                if isinstance(reason, (TimeoutError, socket.timeout)):
                    result = "BLOCKED:timeout"
                elif isinstance(reason, ConnectionRefusedError):
                    result = "BLOCKED:connection_refused"
                else:
                    result = f"PROBE_ERROR:{type(reason).__name__}"
        payload = result.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format, *args):
        return


HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
