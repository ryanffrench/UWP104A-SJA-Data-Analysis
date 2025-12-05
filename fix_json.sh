#!/bin/bash

for FILE in *.json; do
    if [ -f "$FILE" ]; then
        # Read the file and remove trailing whitespace/newlines
        CONTENT=$(<"$FILE")
        CONTENT=$(echo "$CONTENT" | sed 's/[[:space:]]*$//')

        # Fix trailing },] at the very end
        if [[ $CONTENT == *"},]" ]]; then
            CONTENT="${CONTENT%,]}"  # remove the trailing comma
            CONTENT="$CONTENT]"      # add the correct closing bracket
            printf "%s" "$CONTENT" > "$FILE"
            echo "Fixed $FILE"
        fi
    fi
done
