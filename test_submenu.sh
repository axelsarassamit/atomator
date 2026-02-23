#!/bin/bash

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
