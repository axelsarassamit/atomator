#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi

echo "Testing submenu..."
while true; do
    echo "1. Option 1"
    echo "0. Exit"
    read -p "Choice: " choice
    
    case $choice in
        1)
            echo "You chose 1"
            ;;
        0)
            echo "Breaking out..."
            break
            ;;
        *)
            echo "Invalid choice: '$choice'"
            ;;
    esac
done
echo "Back to main"
