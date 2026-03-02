#!/bin/bash
#
# ================================================================
# usb-port-report.sh
# ================================================================
#
# PURPOSE:
#   Display a grouped report of:
#
#     1) Physical USB port topology
#        - Shows ALL USB port paths (even empty ones)
#        - Indicates whether a device is connected
#        - Displays VID:PID and product name
#        - If the device created a /dev node, shows it inline
#
#     2) All enumerated USB devices
#        - Includes root hubs, hubs, and endpoints
#        - Displays bus number, port path, VID:PID, manufacturer, product
#
#
# WHY THIS IS USEFUL:
#   Linux dynamically assigns device names like:
#       /dev/ttyUSB0
#       /dev/sdb
#
#   These can change when devices are unplugged/replugged.
#
#   This script helps correlate:
#
#       Physical USB Port (e.g., 1-1.3)
#             ↓
#       Enumerated USB device
#             ↓
#       /dev node (if one exists)
#
#   This is especially useful when:
#       - Creating persistent udev rules
#       - Binding serial adapters to fixed ports
#       - Debugging USB enumeration issues
#       - Working with USB-RS232 adapters
#
#
# HOW IT WORKS:
#   - Reads topology information from:
#         /sys/bus/usb/devices/
#
#   - Identifies physical port entries (e.g., 1-1, 1-1.2, 3-2)
#   - Skips interface entries (e.g., 1-1:1.0)
#   - Looks for idVendor/idProduct to determine if a device is attached
#   - Searches /sys/class to discover any associated /dev nodes
#
#
# REQUIREMENTS:
#   - Standard Linux system
#   - No root required
#   - Uses sysfs and udev-managed device links
#
#
# EXAMPLE OUTPUT:
#
#   ===============================
#   PHYSICAL USB PORTS
#   ===============================
#
#   Port 1-9      (Bus 1)  1a40:0801  USB 2.0 Hub [Safe]
#   Port 1-9.1    (Bus 1)  1a2c:002e  USB Keyboard   →   /dev/input/event3
#   Port 3-2      (Bus 3)  154b:007a  USB Flash Drive →   /dev/sdb
#   Port 1-9.3    (Bus 1)  EMPTY
#
#
# NOTES:
#   - Root hubs (usb1, usb2, etc.) appear only in the
#     "ALL USB DEVICES" section.
#
#   - Not all USB devices create /dev nodes.
#     Examples:
#         Hubs → No /dev entry
#         Keyboards → /dev/input/eventX
#         Flash drives → /dev/sdX
#         USB serial → /dev/ttyUSBX
#
# ================================================================


echo
echo "==============================="
echo "PHYSICAL USB PORTS"
echo "==============================="
echo

for entry in /sys/bus/usb/devices/[0-9]*; do

    NAME=$(basename "$entry")

    [[ "$NAME" == *:* ]] && continue

    if [[ "$NAME" =~ ^[0-9]+-[0-9]+(\.[0-9]+)*$ ]]; then

        BUS=$(cat "$entry/busnum" 2>/dev/null)
        VID=$(cat "$entry/idVendor" 2>/dev/null)
        PID=$(cat "$entry/idProduct" 2>/dev/null)
        PRODUCT=$(cat "$entry/product" 2>/dev/null)

        DEVNODES=$(find /sys/class -type l 2>/dev/null | grep "$NAME" | while read link; do
            DEVNAME=$(basename "$link")
            case "$link" in
                */tty/*) echo "/dev/$DEVNAME" ;;
                */block/*) echo "/dev/$DEVNAME" ;;
                */input/*) echo "/dev/$DEVNAME" ;;
            esac
        done | sort -u | tr '\n' ' ')

        if [[ -n "$VID" ]]; then
            printf "Port %-8s (Bus %s)  %s:%s  %s" \
                "$NAME" "$BUS" "$VID" "$PID" "${PRODUCT:-Unknown}"

            if [[ -n "$DEVNODES" ]]; then
                printf "   →   %s" "$DEVNODES"
            fi

            echo
        else
            printf "Port %-8s (Bus %s)  EMPTY\n" \
                "$NAME" "$BUS"
        fi
    fi
done | sort -V


echo
echo "==============================="
echo "ALL USB DEVICES"
echo "==============================="
echo

for devpath in /sys/bus/usb/devices/*; do

    NAME=$(basename "$devpath")
    [[ "$NAME" == *:* ]] && continue

    if [[ -f "$devpath/idVendor" ]]; then

        BUS=$(cat "$devpath/busnum" 2>/dev/null)
        VID=$(cat "$devpath/idVendor" 2>/dev/null)
        PID=$(cat "$devpath/idProduct" 2>/dev/null)
        MANUF=$(cat "$devpath/manufacturer" 2>/dev/null)
        PRODUCT=$(cat "$devpath/product" 2>/dev/null)

        printf "Bus %-2s %-8s  %s:%s  %s %s\n" \
            "$BUS" "$NAME" "$VID" "$PID" \
            "${MANUF:-Unknown}" "${PRODUCT:-Unknown}"
    fi
done | sort -V

echo
