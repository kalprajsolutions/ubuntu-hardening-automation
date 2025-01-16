#!/bin/bash

# Path to home directories
BASE_HOME="/home"

# Iterate through each user directory in the base home directory
for USER_HOME in "$BASE_HOME"/*; do
    # Skip if not a directory
    [ -d "$USER_HOME" ] || continue

    # Extract the username from the path
    USER=$(basename "$USER_HOME")

    # Define the htdocs path
    HTDOCS_PATH="$USER_HOME/htdocs"

    # Check if the htdocs directory exists
    if [ -d "$HTDOCS_PATH" ]; then
        # Iterate through each subdirectory inside htdocs (domain directories)
        for DOMAIN_DIR in "$HTDOCS_PATH"/*; do
            # Check if it's a directory and contains wp-config.php
            if [ -d "$DOMAIN_DIR" ] && [ -f "$DOMAIN_DIR/wp-config.php" ]; then
                echo "Checking WordPress integrity for user: $USER, Domain: $DOMAIN_DIR"

                # Run the wp core verify-checksums command as the user
                sudo -u "$USER" -i -- wp core verify-checksums --path="$DOMAIN_DIR"

                # Check the command's exit status
                if [ $? -eq 0 ]; then
                    echo "Integrity check passed for $USER at $DOMAIN_DIR"
                else
                    echo "Integrity check failed for $USER at $DOMAIN_DIR"
                fi
            else
                echo "No WordPress installation found in $DOMAIN_DIR for user: $USER"
            fi
        done
    else
        echo "No htdocs directory found for user: $USER"
    fi
done
