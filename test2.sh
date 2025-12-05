#!/bin/bash

# --- Configuration ---
# ⚠️ REPLACE this URL with the actual, full base URL you identified
API_BASE_URL='https://fsbgeujskf.execute-api.us-west-1.amazonaws.com/production/detail/' 

# Pagination settings
LIMIT=100           # Number of records to fetch per request. Keep this moderate (e.g., 100-500).
START=0             # Starting record index (offset)
DATA_FILE="courses_SS2_Fall_2018.json"

# Filters derived from the application code
# Target: Summer Session 2 2018 (ss2=SS2) AND Fall 2018 (fall=FQ)
FILTERS="ss2=SS2&fall=FQ&year=2018" 

# Initialize the data file as an empty JSON array
echo "[" > "$DATA_FILE"
FIRST_RUN=true
TOTAL_RECORDS=0

echo "Starting scrape for: SS2 2018 and FQ 2018..."
echo "Results will be saved to $DATA_FILE."
echo "----------------------------------------"

# --- Pagination Loop ---

while true; do
    
    # Construct the full request URL
    URL="${API_BASE_URL}?limit=${LIMIT}&start=${START}&${FILTERS}"
    
    echo "Fetching: start=${START}, limit=${LIMIT}..."
    
    # Execute curl request and capture the response
    # -s: Silent/no progress meter
    API_RESPONSE=$(curl -s -X GET "$URL")
    
    # Extract the array of objects using jq
    # We use '.[]' to get objects separated by newlines, not commas, for easy counting/appending
    COURSE_OBJECTS=$(echo "$API_RESPONSE" | jq -c '.[]') 

    # Count the number of items received
    COUNT=$(echo "$COURSE_OBJECTS" | wc -l)
    
    # Stop condition: If no more courses are returned
    if [ "$COUNT" -eq 0 ]; then
        echo "No more data received. Scrape complete."
        break
    fi
    
    # Prepare data for file: join objects with commas, ensuring the last one doesn't have a trailing comma
    # Truncate the final comma when the full line is processed 
    # and remove all newlines, then print.
    DATA_TO_APPEND=$(echo "$COURSE_OBJECTS" | awk '{print}' ORS=',' | sed 's/,$//')
    
    # --- Append to File Logic ---
    
    # If this is not the first chunk of data, we need a comma separator
    if [ "$FIRST_RUN" = false ]; then
        echo -n "," >> "$DATA_FILE"
    fi
    
    # Append the new course data
    echo -n "$DATA_TO_APPEND" >> "$DATA_FILE"
    
    # Update state for the next iteration
    FIRST_RUN=false
    START=$((START + COUNT))
    TOTAL_RECORDS=$((TOTAL_RECORDS + COUNT))

    echo "Successfully fetched $COUNT records. Total scraped so far: $TOTAL_RECORDS"
done

# --- Finalization ---

# Close the JSON array structure
echo "]" >> "$DATA_FILE"

echo "----------------------------------------"
echo "✅ Scrape finished."
echo "Total records scraped: **$TOTAL_RECORDS**"
echo "Full data saved to **$DATA_FILE**"
