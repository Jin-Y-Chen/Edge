"""Poll PSU metrics on an interval."""

import os
import time

from .monitor import read_metrics


def main() -> None:
    interval = float(os.environ.get("POLL_INTERVAL_SEC", "5"))
    print(f"power monitor started (interval={interval}s)")

    while True:
        m = read_metrics()
        parts = [f"source={m.source}"]
        if m.voltage_v is not None:
            parts.append(f"voltage={m.voltage_v:.3f}V")
        if m.current_a is not None:
            parts.append(f"current={m.current_a:.3f}A")
        print(" | ".join(parts))
        time.sleep(interval)


if __name__ == "__main__":
    main()
