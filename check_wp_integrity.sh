#!/bin/bash

# Path to home directories
BASE_HOME="/home"

# Iterate through each user directory in the base home directory
for USER_HOME in "$BASE_HOME"/*; do
    # Skip if not a directory
    [ -d "$USER_HOME" ] || continue

    # Extract the username from the path
    USER=$(basename "$USER_HOME")

    # Define the potential WordPress path
    WP_PATH="$USER_HOME/htdocs"

    # Check if wp-config.php exists in the path (indicating a WordPress installation)
    if [ -f "$WP_PATH/wp-config.php" ]; then
        echo "Checking WordPress integrity for user: $USER, Path: $WP_PATH"

        # Run the wp core verify-checksums command as the user
        sudo -u "$USER" -i -- wp core verify-checksums --path="$WP_PATH"
        
        # Check the command's exit status
        if [ $? -eq 0 ]; then
            echo "Integrity check passed for $USER at $WP_PATH"
        else
            echo "Integrity check failed for $USER at $WP_PATH"
        fi
    else
        echo "No WordPress installation found for user: $USER"
    fi
done
