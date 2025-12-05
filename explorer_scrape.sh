#!/bin/bash


API_BASE_URL='https://fsbgeujskf.execute-api.us-west-1.amazonaws.com/production/detail/' 
LIMIT=100
OUTPUT_DIR="course_data"


mkdir -p "$OUTPUT_DIR"


QUARTERS=("fall=FQ" "winter=WQ" "spring=SQ")
QUARTER_NAMES=("Fall" "Winter" "Spring")
YEARS=(2016 2017 2018 2019 2020 2021 2022)

echo "=========================================="
echo "Starting multi-quarter scrape"
echo "=========================================="


for YEAR in "${YEARS[@]}"; do
    for i in "${!QUARTERS[@]}"; do
        FILTER="${QUARTERS[$i]}"
        QUARTER_NAME="${QUARTER_NAMES[$i]}"
        
        DATA_FILE="${OUTPUT_DIR}/courses_${QUARTER_NAME}_${YEAR}.json"
        
        echo ""
        echo "=========================================="
        echo "Scraping: ${QUARTER_NAME} ${YEAR}"
        echo "File: ${DATA_FILE}"
        echo "=========================================="
        

        echo "[" > "$DATA_FILE"
        
        START=0
        FIRST_RUN=true
        TOTAL_RECORDS=0
        

        while true; do
            URL="${API_BASE_URL}?limit=${LIMIT}&start=${START}&${FILTER}&year=${YEAR}"
            
            echo "  Fetching: start=${START}, limit=${LIMIT}..."
            
            API_RESPONSE=$(curl -s -X GET "$URL")
            COURSE_OBJECTS=$(echo "$API_RESPONSE" | jq -c '.[]') 
            COUNT=$(echo "$COURSE_OBJECTS" | wc -l)
            

            if [ "$COUNT" -le 1 ]; then
                echo "  Only ${COUNT} record(s) returned. End of data for this quarter."
                if [ "$COUNT" -eq 1 ]; then
                    if [ "$FIRST_RUN" = false ]; then
                        echo -n "," >> "$DATA_FILE"
                    fi
                    echo -n "$COURSE_OBJECTS" >> "$DATA_FILE"
                    TOTAL_RECORDS=$((TOTAL_RECORDS + 1))
                fi
                break
            fi
            
            DATA_TO_APPEND=$(echo "$COURSE_OBJECTS" | awk '{print}' ORS=',' | sed 's/,$//')
            
            if [ "$FIRST_RUN" = false ]; then
                echo -n "," >> "$DATA_FILE"
            fi
            
            echo -n "$DATA_TO_APPEND" >> "$DATA_FILE"
            
            FIRST_RUN=false
            START=$((START + COUNT))
            TOTAL_RECORDS=$((TOTAL_RECORDS + COUNT))
            
            echo "  Fetched ${COUNT} records. Total: ${TOTAL_RECORDS}"
        done
        
        echo "]" >> "$DATA_FILE"
        
        echo "Completed ${QUARTER_NAME} ${YEAR}: ${TOTAL_RECORDS} records"
        echo "File closed: ${DATA_FILE}"
    done
done

echo ""
echo "=========================================="
echo "All quarters scraped successfully"
echo "Data saved in: ${OUTPUT_DIR}/"
echo "=========================================="
