"""Idle gimbal service: center on start, optional sweep from env."""

import os
import time

from .gimbal import from_env


def main() -> None:
    yaw = float(os.environ.get("GIMBAL_YAW", "0"))
    pitch = float(os.environ.get("GIMBAL_PITCH", "0"))
    sweep = os.environ.get("GIMBAL_SWEEP", "").lower() in ("1", "true", "yes")

    gimbal = from_env()
    try:
        print("centering gimbal ...")
        gimbal.center()
        time.sleep(1)
        gimbal.set_angles(yaw, pitch)
        print(f"set yaw={yaw} pitch={pitch}")

        if sweep:
            for angle in (-30, 0, 30, 0):
                gimbal.set_angles(angle, pitch)
                time.sleep(2)

        print("gimbal ready — holding position")
        while True:
            time.sleep(60)
    finally:
        gimbal.close()


if __name__ == "__main__":
    main()
