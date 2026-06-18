# Edge node connection settings — edit for your setup.
#
# Sourced by remote_ssh, connect_wifi, and other scripts.
# Env vars still override these at runtime:
#   BOARD_IP=10.0.0.5 ./remote_ssh edge

BOARD_USER="${BOARD_USER:-edge}"
BOARD_IP="${BOARD_IP:-192.168.1.28}"           # LAN / Wi-Fi
BOARD_IP_USB="${BOARD_IP_USB:-192.168.55.1}"   # USB gadget (Jetson side)
