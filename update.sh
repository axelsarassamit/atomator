#!/bin/bash
set +e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
TARGET_DIR="/remote_tools"

echo -e "${CYAN}=== Update Remote Management Scripts ===${NC}"
echo ""

# Show current version
if [ -f "$TARGET_DIR/version.txt" ]; then
    CURRENT=$(head -1 "$TARGET_DIR/version.txt")
    INSTALLED=$(tail -1 "$TARGET_DIR/version.txt")
    echo -e "  Current version:   ${GREEN}v${CURRENT}${NC}  (installed ${INSTALLED})"
else
    CURRENT="unknown"
    echo -e "  Current version:   ${RED}unknown${NC}"
fi

# Find update file in /remote_tools/
UPDATE_FILE=$(ls -1 "$TARGET_DIR"/update_v*.sh 2>/dev/null | sort -V | tail -1)

if [ -z "$UPDATE_FILE" ]; then
    echo ""
    echo -e "${RED}No update found.${NC}"
    echo ""
    echo "Place the update file in /remote_tools/ named like: update_v1.1.0.sh"
    echo "  Example: scp update_v1.1.0.sh root@server:/remote_tools/"
    exit 1
fi

# Extract version from filename: update_v1.2.3.sh -> 1.2.3
FILENAME=$(basename "$UPDATE_FILE")
NEW_VERSION=$(echo "$FILENAME" | sed 's/update_v//;s/\.sh$//')

echo -e "  New version:       ${YELLOW}v${NEW_VERSION}${NC}  ($FILENAME)"
echo ""

# Same version check
if [ "$CURRENT" = "$NEW_VERSION" ]; then
    echo -e "${YELLOW}Same version. Reinstall anyway?${NC}"
    read -p "(yes/no): " confirm
    if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
else
    read -p "Update v${CURRENT} -> v${NEW_VERSION}? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
fi

echo ""

# Backup config files
echo "Backing up config files..."
for f in hosts.txt mac_addresses.txt wallpapers.txt; do
    if [ -f "$TARGET_DIR/$f" ]; then
        cp "$TARGET_DIR/$f" "/root/${f}.backup"
        echo "  Backed up: $f -> /root/${f}.backup"
    fi
done
echo ""

# Run the installer
echo "Running $FILENAME..."
echo ""
bash "$UPDATE_FILE"

# Restore config files if missing
for f in hosts.txt mac_addresses.txt wallpapers.txt; do
    if [ -f "/root/${f}.backup" ] && [ ! -f "$TARGET_DIR/$f" ]; then
        cp "/root/${f}.backup" "$TARGET_DIR/$f"
        echo "Restored: $f"
    fi
done

echo ""
echo -e "${GREEN}Update complete.${NC}"
echo "  Update file kept: $UPDATE_FILE"
