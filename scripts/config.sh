# Edge node connection settings — edit for your setup.
#
# Sourced by host scripts (inject, reject, remote_ssh, uninstall).

BOARD_USER="${BOARD_USER:-edge}"
BOARD_IP="${BOARD_IP:-192.168.1.28}"           # LAN / Wi-Fi
BOARD_IP_USB="${BOARD_IP_USB:-192.168.55.1}"   # USB gadget (Jetson side)
