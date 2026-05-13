#!/bin/bash

# ============================================
# FirmAE Complete Cleanup Script
# Kills all QEMU processes, deletes TAP devices,
# unmounts filesystems, and cleans up temp files.
# ============================================

set -e
set -u

if [ -e ./firmae.config ]; then
    source ./firmae.config
elif [ -e ../firmae.config ]; then
    source ../firmae.config
else
    echo "Error: Could not find 'firmae.config'!"
    exit 1
fi

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}[*] FirmAE Complete Cleanup${NC}"
echo "======================================"

# ================================
# 1. Kill all QEMU processes
# ================================
echo -e "${YELLOW}[*] Killing QEMU processes...${NC}"
QEMU_PIDS=$(ps -ef | grep -E '(qemu-system|qemu)' | grep -v grep | awk '{print $2}' || true)
if [ -n "$QEMU_PIDS" ]; then
    echo "  Killing QEMU PIDs: $QEMU_PIDS"
    sudo kill -9 $QEMU_PIDS 2>/dev/null || true
    sleep 1
    echo -e "  ${GREEN}✓${NC} QEMU processes killed"
else
    echo -e "  ${GREEN}✓${NC} No QEMU processes found"
fi

# Also kill any run.sh scripts from scratch
echo -e "${YELLOW}[*] Killing remaining emulation scripts...${NC}"
RUN_PIDS=$(ps -ef | grep 'scratch/[0-9]\+/run\.sh' | grep -v grep | awk '{print $2}' || true)
if [ -n "$RUN_PIDS" ]; then
    echo "  Killing script PIDs: $RUN_PIDS"
    kill -9 $RUN_PIDS 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} Emulation scripts killed"
else
    echo -e "  ${GREEN}✓${NC} No emulation scripts found"
fi

# ================================
# 2. Delete all TAP devices
# ================================
echo -e "${YELLOW}[*] Deleting TAP devices...${NC}"
TAP_DEVICES=$(ip link show | grep -oE 'tap[0-9]+_[0-9]+' || true)
if [ -n "$TAP_DEVICES" ]; then
    for tap in $TAP_DEVICES; do
        echo "  Deleting $tap..."
        sudo ip link set "$tap" down 2>/dev/null || true
        sudo tunctl -d "$tap" 2>/dev/null || true
    done
    echo -e "  ${GREEN}✓${NC} TAP devices deleted"
else
    echo -e "  ${GREEN}✓${NC} No TAP devices found"
fi

# Also clean up any remaining tap devices that tunctl -d may have missed
for tap in /sys/class/net/tap*; do
    if [ -e "$tap" ]; then
        tap_name=$(basename "$tap")
        echo "  Force removing $tap_name..."
        sudo ip link set "$tap_name" down 2>/dev/null || true
        sudo tunctl -d "$tap_name" 2>/dev/null || true
    fi
done

# ================================
# 3. Unmount any mounted firmware filesystems
# ================================
echo -e "${YELLOW}[*] Unmounting firmware filesystems...${NC}"
MOUNTED=$(mount | grep "${SCRATCH_DIR}" | awk '{print $1}' || true)
if [ -n "$MOUNTED" ]; then
    for dev in $MOUNTED; do
        echo "  Unmounting $dev..."
        sudo umount -f "$dev" 2>/dev/null || true
    done
    echo -e "  ${GREEN}✓${NC} Filesystems unmounted"
else
    echo -e "  ${GREEN}✓${NC} No firmware filesystems mounted"
fi

# Also unmount any loop devices from scratch images
LOOP_DEVS=$(losetup -j "${SCRATCH_DIR}" 2>/dev/null | grep -oE '/dev/loop[0-9]+' || true)
if [ -n "$LOOP_DEVS" ]; then
    for loop in $LOOP_DEVS; do
        echo "  Detaching $loop..."
        sudo losetup -d "$loop" 2>/dev/null || true
    done
    echo -e "  ${GREEN}✓${NC} Loop devices detached"
fi

# ================================
# 4. Clean up QEMU temp sockets
# ================================
echo -e "${YELLOW}[*] Cleaning up QEMU temp files...${NC}"
QEMU_TMP=$(ls /tmp/qemu.* 2>/dev/null || true)
if [ -n "$QEMU_TMP" ]; then
    sudo rm -f /tmp/qemu.* 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} QEMU temp files removed"
else
    echo -e "  ${GREEN}✓${NC} No QEMU temp files found"
fi

# ================================
# 5. Kill any leftover network services
#    (like check_network sub-processes)
# ================================
echo -e "${YELLOW}[*] Cleaning up leftover network checks...${NC}"
NET_CHECK_PIDS=$(ps -ef | grep 'check_network' | grep -v grep | awk '{print $2}' || true)
if [ -n "$NET_CHECK_PIDS" ]; then
    kill -9 $NET_CHECK_PIDS 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} Network checks stopped"
else
    echo -e "  ${GREEN}✓${NC} No stray network checks"
fi

echo "======================================"
echo -e "${GREEN}[+] Cleanup complete!${NC}"
