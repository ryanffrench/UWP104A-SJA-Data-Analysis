#!/bin/bash

# Usage: ./analyze_perfect_a_classes.sh course_data/*.json

if [ $# -eq 0 ]; then
    echo "Usage: $0 <json_files...>"
    echo "Example: $0 course_data/*.json"
    exit 1
fi

OUTPUT_FILE="perfect_a_classes.txt"
TEMP_DIR=$(mktemp -d)

echo "=================================="
echo "PERFECT A CLASSES ANALYSIS"
echo "=================================="
echo ""
echo "Processing files..."

# Combine all files and filter for classes with ONLY A+, A-, A grades
for file in "$@"; do
    echo "  - $(basename "$file")"
    
    # Check if file is not empty
    file_size=$(jq 'length' "$file" 2>/dev/null || echo "0")
    if [ "$file_size" -gt 0 ]; then
        # Select courses where only A+, A-, or A grades were given (all other grades = 0)
        jq -c '.[] | select(
            ((.aplus // 0) > 0 or (.a // 0) > 0 or (.aminus // 0) > 0) and
            (.bplus // 0) == 0 and (.b // 0) == 0 and (.bminus // 0) == 0 and
            (.cplus // 0) == 0 and (.c // 0) == 0 and (.cminus // 0) == 0 and
            (.dplus // 0) == 0 and (.d // 0) == 0 and (.dminus // 0) == 0 and
            (.f // 0) == 0 and (.I // 0) == 0 and
            (.P // 0) == 0 and (.NP // 0) == 0 and (.Y // 0) == 0
        )' "$file" 2>/dev/null >> "$TEMP_DIR/perfect_a_courses.json" || true
        
        jq -c '.[]' "$file" 2>/dev/null >> "$TEMP_DIR/all_courses.json" || true
    fi
done

# Check if we have any data
if [ ! -f "$TEMP_DIR/perfect_a_courses.json" ] || [ ! -s "$TEMP_DIR/perfect_a_courses.json" ]; then
    echo ""
    echo "No classes found with only A+, A-, or A grades!"
    rm -rf "$TEMP_DIR"
    exit 0
fi

echo ""
echo "=================================="
echo "ANALYSIS RESULTS"
echo "=================================="

# Start output file
cat > "$OUTPUT_FILE" << 'EOF'
================================
PERFECT A CLASSES ANALYSIS
Classes with ONLY A+, A-, or A grades
================================

EOF

# 1. Total perfect A classes per quarter
echo ""
echo "1. PERFECT A CLASSES PER QUARTER" | tee -a "$OUTPUT_FILE"
echo "=================================" | tee -a "$OUTPUT_FILE"

jq -r '.quarter' "$TEMP_DIR/all_courses.json" 2>/dev/null | sort -u > "$TEMP_DIR/all_quarters.txt"

while read quarter; do
    perfect_count=$(jq -r "select(.quarter == \"$quarter\")" "$TEMP_DIR/perfect_a_courses.json" 2>/dev/null | wc -l)
    echo "$quarter: $perfect_count classes"
done < "$TEMP_DIR/all_quarters.txt" | tee -a "$OUTPUT_FILE"

# 2. List all perfect A classes by quarter
echo ""
echo "2. ALL PERFECT A CLASSES (BY QUARTER)" | tee -a "$OUTPUT_FILE"
echo "======================================" | tee -a "$OUTPUT_FILE"

while read quarter; do
    perfect_count=$(jq -r "select(.quarter == \"$quarter\")" "$TEMP_DIR/perfect_a_courses.json" 2>/dev/null | wc -l)
    
    if [ "$perfect_count" -gt 0 ]; then
        echo ""
        echo "Quarter: $quarter" | tee -a "$OUTPUT_FILE"
        echo "-----------------" | tee -a "$OUTPUT_FILE"
        jq -r "select(.quarter == \"$quarter\") | \"\(.course_id) - \(.name) (\(.instructor)): A+=\(.aplus // 0), A=\(.a // 0), A-=\(.aminus // 0)\"" \
            "$TEMP_DIR/perfect_a_courses.json" 2>/dev/null | sort | nl | tee -a "$OUTPUT_FILE"
    fi
done < "$TEMP_DIR/all_quarters.txt"

# 3. Top instructors with most perfect A classes
echo ""
echo "3. TOP 10 INSTRUCTORS WITH MOST PERFECT A CLASSES" | tee -a "$OUTPUT_FILE"
echo "==================================================" | tee -a "$OUTPUT_FILE"

jq -r '.instructor' "$TEMP_DIR/perfect_a_courses.json" 2>/dev/null | sort | uniq -c | sort -rn | head -10 | \
awk 'BEGIN {count=1} {printf "%2d. %s: %d classes\n", count++, substr($0, index($0,$2)), $1}' | tee -a "$OUTPUT_FILE"

# 4. Summary statistics
echo ""
echo "4. SUMMARY STATISTICS" | tee -a "$OUTPUT_FILE"
echo "=====================" | tee -a "$OUTPUT_FILE"

total_perfect=$(wc -l < "$TEMP_DIR/perfect_a_courses.json")
total_all=$(wc -l < "$TEMP_DIR/all_courses.json")

if [ "$total_all" -gt 0 ]; then
    pct_perfect=$(echo "scale=2; ($total_perfect / $total_all) * 100" | bc)
else
    pct_perfect="0.00"
fi

# Calculate total A grades in perfect classes
total_a_plus=$(jq -r '.aplus // 0' "$TEMP_DIR/perfect_a_courses.json" 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
total_a=$(jq -r '.a // 0' "$TEMP_DIR/perfect_a_courses.json" 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
total_a_minus=$(jq -r '.aminus // 0' "$TEMP_DIR/perfect_a_courses.json" 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
total_students=$((total_a_plus + total_a + total_a_minus))

echo "Total classes with only A+/A/A- grades: $total_perfect" | tee -a "$OUTPUT_FILE"
echo "Total classes analyzed: $total_all" | tee -a "$OUTPUT_FILE"
echo "Percentage of perfect A classes: ${pct_perfect}%" | tee -a "$OUTPUT_FILE"
echo ""
echo "Total students receiving grades in these classes:" | tee -a "$OUTPUT_FILE"
echo "  A+: $total_a_plus" | tee -a "$OUTPUT_FILE"
echo "  A:  $total_a" | tee -a "$OUTPUT_FILE"
echo "  A-: $total_a_minus" | tee -a "$OUTPUT_FILE"
echo "  Total: $total_students students" | tee -a "$OUTPUT_FILE"

# 5. Years analyzed
echo ""
echo "5. QUARTERS ANALYZED" | tee -a "$OUTPUT_FILE"
echo "====================" | tee -a "$OUTPUT_FILE"
jq -r '.quarter' "$TEMP_DIR/all_courses.json" 2>/dev/null | sort -u | tee -a "$OUTPUT_FILE"

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "=================================="
echo "Analysis complete!"
echo "Full report saved to: $OUTPUT_FILE"
echo "=================================="
