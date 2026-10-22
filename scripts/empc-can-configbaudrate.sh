#!/bin/bash

export LC_ALL=C

if [ "$EUID" -ne 0 ]; then
    echo "This script should be run as root." >&2
    exit 1
fi

if ! command -v whiptail >/dev/null 2>&1; then
    echo "whiptail is required to configure CAN baud rates." >&2
    exit 1
fi

if [ ! -x /usr/janz/bin/ixconfig ]; then
    echo "/usr/janz/bin/ixconfig is missing or not executable." >&2
    exit 1
fi
IXCONFIG_OUTPUT=$(/usr/janz/bin/ixconfig 2>&1) || {
    echo "Could not read CAN modules from ixconfig." >&2
    exit 1
}
CANS=$(printf '%s\n' "$IXCONFIG_OUTPUT" | grep -c 'iX-Module.*CAN' || true)
if ! [[ "$CANS" =~ ^[0-9]+$ ]]; then
    echo "Could not determine the number of CAN interfaces." >&2
    exit 1
fi

CONFIG_FILE=/etc/empc-can.conf
CONFIG_CHANGED=false

for ((can = 0; can < CANS; can++)); do
    interface="can$can"
    BAUDRATE=$(whiptail --title "Configure $interface baud rate" --radiolist \
        "What is the baud rate of $interface?" 15 60 8 \
        "1000" "1000 kBit/s" OFF \
        "500" "500 kBit/s" OFF \
        "250" "250 kBit/s (default)" ON \
        "125" "125 kBit/s" OFF \
        "100" "100 kBit/s" OFF \
        "50" "50 kBit/s" OFF \
        "20" "20 kBit/s" OFF \
        "10" "10 kBit/s" OFF 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ "$exitstatus" -ne 0 ]; then
        continue
    fi

    bitrate="${BAUDRATE}000"
    if ! [[ "$bitrate" =~ ^(1000000|500000|250000|125000|100000|50000|20000|10000)$ ]]; then
        echo "Invalid baud rate selected for $interface: $BAUDRATE" >&2
        exit 1
    fi

    tmpfile=$(mktemp /etc/.empc-can.conf.XXXXXX) || exit 1
    if [ -f "$CONFIG_FILE" ]; then
        if ! awk -v interface="$interface" '$1 != interface { print }' "$CONFIG_FILE" > "$tmpfile"; then
            rm -f "$tmpfile"
            echo "Could not read $CONFIG_FILE." >&2
            exit 1
        fi
    fi
    if ! printf '%s %s\n' "$interface" "$bitrate" >> "$tmpfile"; then
        rm -f "$tmpfile"
        echo "Could not write $CONFIG_FILE." >&2
        exit 1
    fi
    chmod 600 "$tmpfile"
    if ! mv "$tmpfile" "$CONFIG_FILE"; then
        rm -f "$tmpfile"
        echo "Could not install $CONFIG_FILE." >&2
        exit 1
    fi
    CONFIG_CHANGED=true
done

if [ "$CONFIG_CHANGED" = true ]; then
    if ! systemctl restart empc-baudrate-config.service; then
        echo "Could not restart empc-baudrate-config.service." >&2
        exit 1
    fi
fi
