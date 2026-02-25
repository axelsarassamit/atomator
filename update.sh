#!/bin/bash
set +e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
TARGET_DIR="/remote_tools"
GITHUB_URL="https://raw.githubusercontent.com/axelsarassamit/atomator/main/quick_install.sh"

echo -e "${CYAN}=== Atomator - Update Scripts ===${NC}"
echo ""

# Show current version
if [ -f "$TARGET_DIR/version.txt" ]; then
    CURRENT=$(head -1 "$TARGET_DIR/version.txt")
    INSTALLED=$(tail -1 "$TARGET_DIR/version.txt")
    echo -e "  Current version:   ${GREEN}v.${CURRENT}${NC}  (installed ${INSTALLED})"
else
    CURRENT="unknown"
    echo -e "  Current version:   ${RED}unknown${NC}"
fi
echo ""

# Check for local update files
LOCAL_FILE=$(ls -1 "$TARGET_DIR"/updates/update_v*.sh 2>/dev/null | sort -V | tail -1)
if [ -z "$LOCAL_FILE" ]; then
    LOCAL_FILE=$(ls -1 "$TARGET_DIR"/update_v*.sh 2>/dev/null | sort -V | tail -1)
fi

echo -e "${YELLOW}Update options:${NC}"
echo ""
if [ -n "$LOCAL_FILE" ]; then
    LOCAL_NAME=$(basename "$LOCAL_FILE")
    LOCAL_VER=$(echo "$LOCAL_NAME" | sed 's/update_v\.//;s/update_v//;s/\.sh$//')
    echo -e "  ${YELLOW}1.${NC} Update from local file  (${LOCAL_NAME} - v.${LOCAL_VER})"
else
    echo -e "  ${RED}1.${NC} Update from local file  (no update file found)"
fi
echo -e "  ${YELLOW}2.${NC} Download latest from GitHub"
echo -e "  ${YELLOW}3.${NC} Revert to a previous version"
echo -e "  ${RED}0.${NC} Cancel"
echo ""
read -p "  Choice [0-3]: " update_choice

case $update_choice in
    1)
        if [ -z "$LOCAL_FILE" ]; then
            echo ""
            echo -e "${RED}No local update file found.${NC}"
            exit 1
        fi
        UPDATE_FILE="$LOCAL_FILE"
        NEW_VERSION="$LOCAL_VER"
        ;;
    2)
        echo ""
        echo "Downloading from GitHub..."
        TMP_FILE="/tmp/automator_github_update.sh"
        curl -sL "$GITHUB_URL" -o "$TMP_FILE"
        if [ ! -s "$TMP_FILE" ]; then
            echo -e "${RED}Download failed. Check your internet connection.${NC}"
            exit 1
        fi
        NEW_VERSION=$(grep '^VERSION=' "$TMP_FILE" | head -1 | cut -d'"' -f2)
        if [ -z "$NEW_VERSION" ]; then
            echo -e "${RED}Could not detect version from downloaded file.${NC}"
            exit 1
        fi
        echo -e "  Downloaded version: ${YELLOW}v.${NEW_VERSION}${NC}"
        mkdir -p "$TARGET_DIR/updates"
        UPDATE_FILE="$TARGET_DIR/updates/update_v.${NEW_VERSION}.sh"
        cp "$TMP_FILE" "$UPDATE_FILE"
        chmod +x "$UPDATE_FILE"
        rm -f "$TMP_FILE"
        ;;
    3)
        echo ""
        echo -e "${CYAN}Available versions:${NC}"
        echo ""
        UPDATE_FILES=$(ls -1 "$TARGET_DIR"/updates/update_v*.sh 2>/dev/null | sort -V)
        if [ -z "$UPDATE_FILES" ]; then
            UPDATE_FILES=$(ls -1 "$TARGET_DIR"/update_v*.sh 2>/dev/null | sort -V)
        fi
        if [ -z "$UPDATE_FILES" ]; then
            echo -e "${RED}No previous versions found.${NC}"
            exit 1
        fi
        i=1
        declare -a VERSION_FILES
        while IFS= read -r f; do
            FNAME=$(basename "$f")
            FVER=$(echo "$FNAME" | sed 's/update_v\.//;s/update_v//;s/\.sh$//')
            if [ "$FVER" = "$CURRENT" ]; then
                echo -e "  ${YELLOW}${i}.${NC} ${FNAME}  ${GREEN}<-- current${NC}"
            else
                echo -e "  ${YELLOW}${i}.${NC} ${FNAME}"
            fi
            VERSION_FILES[$i]="$f"
            i=$((i + 1))
        done <<< "$UPDATE_FILES"
        echo ""
        read -p "  Select version [1-$((i-1))]: " ver_choice
        if [ -z "$ver_choice" ] || [ "$ver_choice" -lt 1 ] 2>/dev/null || [ "$ver_choice" -ge "$i" ] 2>/dev/null; then
            echo "Cancelled."
            exit 0
        fi
        UPDATE_FILE="${VERSION_FILES[$ver_choice]}"
        NEW_VERSION=$(basename "$UPDATE_FILE" | sed 's/update_v\.//;s/update_v//;s/\.sh$//')
        ;;
    *)
        echo "Cancelled."
        exit 0
        ;;
esac

echo ""

# Show changelog from the new version being installed
NEW_CHANGELOG=$(sed -n "/cat > CHANGELOG.md << 'CLEOF'/,/^CLEOF$/{/cat > CHANGELOG.md/d;/^CLEOF$/d;p;}" "$UPDATE_FILE" 2>/dev/null)
if [ -n "$NEW_CHANGELOG" ]; then
    echo -e "${CYAN}Version changes (new version):${NC}"
    echo "$NEW_CHANGELOG"
    echo ""
elif [ -f "$TARGET_DIR/CHANGELOG.md" ]; then
    echo -e "${CYAN}Version changes:${NC}"
    cat "$TARGET_DIR/CHANGELOG.md"
    echo ""
fi

# Version comparison
if [ "$CURRENT" = "$NEW_VERSION" ]; then
    echo -e "${YELLOW}Same version (v.${NEW_VERSION}). Reinstall anyway?${NC}"
    read -p "(yes/no): " confirm
    if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
else
    echo -e "  Update: ${GREEN}v.${CURRENT}${NC} -> ${YELLOW}v.${NEW_VERSION}${NC}"
    read -p "Proceed? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
fi

echo ""

# Backup config files
echo "Backing up config files..."
for f in hosts.txt mac_addresses.txt wallpapers.txt credentials.conf watchdog_hosts.conf; do
    if [ -f "$TARGET_DIR/$f" ]; then
        cp "$TARGET_DIR/$f" "/root/${f}.backup"
        echo "  Backed up: $f -> /root/${f}.backup"
    fi
done
echo ""

# Run the installer
FILENAME=$(basename "$UPDATE_FILE")
echo "Running $FILENAME..."
echo ""
bash "$UPDATE_FILE"

# Restore config files if missing
for f in hosts.txt mac_addresses.txt wallpapers.txt credentials.conf watchdog_hosts.conf; do
    if [ -f "/root/${f}.backup" ] && [ ! -f "$TARGET_DIR/$f" ]; then
        cp "/root/${f}.backup" "$TARGET_DIR/$f"
        echo "Restored: $f"
    fi
done

echo ""
echo -e "${GREEN}Update complete.${NC}"
echo "  Update file kept: $UPDATE_FILE"
