#!/usr/bin/env python3
"""One-shot network policy probe.

Runs a single outbound attempt against the victim's internal Service DNS URL
and prints the outcome on stdout, so the job log captures it.

Result contract (single line):
    CONNECTED:<status>[:<body>]   the target was reachable
    BLOCKED:timeout               the network policy dropped the connection
    BLOCKED:<ExceptionName>       the connection was refused/failed
    ERROR:<ExceptionName>         unexpected failure inside the probe
"""

import os
import socket
from urllib.error import HTTPError, URLError
from urllib.request import urlopen

TARGET_URL = os.environ["NETWORK_POLICY_TARGET_URL"]


def probe():

    try:
        try:
            with urlopen(TARGET_URL, timeout=3) as response:

                body = response.read(4096).decode(
                    "utf-8", errors="replace"
                )

                result = f"CONNECTED:{response.status}:{body}"

        except HTTPError as exc:
            result = f"CONNECTED:{exc.code}"

        except (TimeoutError, socket.timeout):
            result = "BLOCKED:timeout"

        except URLError as exc:

            if isinstance(exc.reason, (TimeoutError, socket.timeout)):
                result = "BLOCKED:timeout"
            else:
                result = f"BLOCKED:{type(exc.reason).__name__}"

        except OSError as exc:
            result = f"BLOCKED:{type(exc).__name__}"

    except Exception as exc:
        result = f"ERROR:{type(exc).__name__}"

    return result


def main():

    print(probe(), flush=True)


if __name__ == "__main__":
    main()
