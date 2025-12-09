#!/bin/bash

# Usage: ./analyze_y_grades.sh course_data/*.json

if [ $# -eq 0 ]; then
    echo "Usage: $0 <json_files...>"
    echo "Example: $0 course_data/*.json"
    exit 1
fi

OUTPUT_FILE="y_grade_analysis.txt"
TEMP_DIR=$(mktemp -d)

echo "=================================="
echo "Y GRADE ANALYSIS REPORT"
echo "=================================="
echo ""
echo "Processing files..."

# Combine all files
for file in "$@"; do
    echo "  - $(basename "$file")"
    
    # Check if file is not empty (skip empty arrays)
    file_size=$(jq 'length' "$file" 2>/dev/null || echo "0")
    if [ "$file_size" -gt 0 ]; then
        jq -c '.[]' "$file" 2>/dev/null >> "$TEMP_DIR/all_courses_raw.json" || true
    fi
done

# Group courses by quarter + course_id + instructor and sum Y grades
# This ensures multiple sections of same course taught by same instructor = 1 course
if [ -f "$TEMP_DIR/all_courses_raw.json" ]; then
    jq -s 'group_by([.quarter, .course_id, .instructor]) | 
           map({
             quarter: .[0].quarter,
             course_id: .[0].course_id,
             name: .[0].name,
             instructor: .[0].instructor,
             Y: map(.Y) | add
           }) | .[]' "$TEMP_DIR/all_courses_raw.json" > "$TEMP_DIR/all_courses_grouped.json"
    
    # Create all_courses.json (all grouped courses)
    jq -c '.' "$TEMP_DIR/all_courses_grouped.json" > "$TEMP_DIR/all_courses.json"
    
    # Create all_y_courses.json (only courses with Y > 0)
    jq -c 'select(.Y > 0)' "$TEMP_DIR/all_courses_grouped.json" > "$TEMP_DIR/all_y_courses.json"
fi

# Check if we have any data
if [ ! -f "$TEMP_DIR/all_y_courses.json" ] || [ ! -s "$TEMP_DIR/all_y_courses.json" ]; then
    echo ""
    echo "ERROR: No courses with Y grades found!"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo ""
echo "=================================="
echo "ANALYSIS RESULTS"
echo "=================================="

# Start output file
cat > "$OUTPUT_FILE" << 'EOF'
================================
Y GRADE ANALYSIS REPORT
================================

EOF

# 1. Total Y grades per quarter
echo ""
echo "1. TOTAL Y GRADES PER QUARTER" | tee -a "$OUTPUT_FILE"
echo "==============================" | tee -a "$OUTPUT_FILE"

# Get ALL unique quarters from all courses
jq -r '.quarter' "$TEMP_DIR/all_courses.json" 2>/dev/null | sort -u > "$TEMP_DIR/all_quarters.txt"


while read quarter; do
    y_total=$(jq -r "select(.quarter == \"$quarter\") | .Y" "$TEMP_DIR/all_y_courses.json" 2>/dev/null | \
              awk '{sum+=$1} END {print sum+0}')
    y_courses=$(jq -r "select(.quarter == \"$quarter\")" "$TEMP_DIR/all_y_courses.json" 2>/dev/null | wc -l)
    
    if [ "$y_total" -gt 0 ]; then
        echo "$quarter: $y_total Y grades across $y_courses courses"
    else
        echo "$quarter: 0 Y grades"
    fi
done < "$TEMP_DIR/all_quarters.txt" | tee -a "$OUTPUT_FILE"


echo ""
echo "2. TOP 10 CLASSES WITH MOST Y GRADES (PER QUARTER)" | tee -a "$OUTPUT_FILE"
echo "===================================================" | tee -a "$OUTPUT_FILE"


while read quarter; do

    y_count=$(jq -r "select(.quarter == \"$quarter\")" "$TEMP_DIR/all_y_courses.json" 2>/dev/null | wc -l)
    
    if [ "$y_count" -gt 0 ]; then
        echo ""
        echo "Quarter: $quarter" | tee -a "$OUTPUT_FILE"
        echo "-----------------" | tee -a "$OUTPUT_FILE"
        jq -r "select(.quarter == \"$quarter\") | \"\(.course_id) - \(.name) (\(.instructor)): \(.Y) Y grades\"" "$TEMP_DIR/all_y_courses.json" 2>/dev/null | \
        sort -t: -k2 -nr | head -10 | nl | tee -a "$OUTPUT_FILE"
    fi
done < "$TEMP_DIR/all_quarters.txt"


echo ""
echo "3. COURSES WITH Y GRADES vs TOTAL COURSES PER QUARTER" | tee -a "$OUTPUT_FILE"
echo "======================================================" | tee -a "$OUTPUT_FILE"


jq -r '.quarter' "$TEMP_DIR/all_y_courses.json" 2>/dev/null | sort | uniq -c | \
awk '{print $2 " " $1}' > "$TEMP_DIR/y_course_counts.txt"


jq -r '.quarter' "$TEMP_DIR/all_courses.json" 2>/dev/null | sort | uniq -c | \
awk '{print $2 " " $1}' > "$TEMP_DIR/all_course_counts.txt"


join "$TEMP_DIR/y_course_counts.txt" "$TEMP_DIR/all_course_counts.txt" 2>/dev/null | \
awk '{printf "%s: %d courses with Y grades / %d total courses (%.1f%%)\n", $1, $2, $3, ($2/$3)*100}' | \
sort | tee -a "$OUTPUT_FILE"


echo ""
echo "4. TOTAL Y GRADES PER YEAR" | tee -a "$OUTPUT_FILE"
echo "==========================" | tee -a "$OUTPUT_FILE"


jq -r '.quarter' "$TEMP_DIR/all_courses.json" 2>/dev/null | \
grep -oE '[0-9]{4}' | sort -u > "$TEMP_DIR/years.txt"

while read year; do
    total=$(jq -r "select(.quarter | contains(\"$year\")) | .Y" "$TEMP_DIR/all_y_courses.json" 2>/dev/null | \
            awk '{sum+=$1} END {print sum+0}')
    
    courses_with_y=$(jq -r "select(.quarter | contains(\"$year\"))" "$TEMP_DIR/all_y_courses.json" 2>/dev/null | wc -l)
    
    total_courses=$(jq -r "select(.quarter | contains(\"$year\"))" "$TEMP_DIR/all_courses.json" 2>/dev/null | wc -l)
    
    echo "$year: $total Y grades across $courses_with_y courses (of $total_courses total)" | tee -a "$OUTPUT_FILE"
done < "$TEMP_DIR/years.txt"


echo ""
echo "5. TOP 10 INSTRUCTORS WITH MOST Y GRADES (ALL QUARTERS)" | tee -a "$OUTPUT_FILE"
echo "========================================================" | tee -a "$OUTPUT_FILE"


jq -r '"\(.instructor)|\(.Y)"' "$TEMP_DIR/all_y_courses.json" 2>/dev/null > "$TEMP_DIR/instructor_y.txt"


awk -F'|' '{
    instructor[$1] += $2
} END {
    for (i in instructor) {
        print instructor[i] "|" i
    }
}' "$TEMP_DIR/instructor_y.txt" | \
sort -t'|' -k1 -nr | head -10 | \
awk -F'|' 'BEGIN {count=1} {printf "%2d. %s: %d Y grades\n", count++, $2, $1}' | tee -a "$OUTPUT_FILE"

echo ""
echo "6. SUMMARY STATISTICS" | tee -a "$OUTPUT_FILE"
echo "=====================" | tee -a "$OUTPUT_FILE"

total_y_grades=$(jq -r '.Y' "$TEMP_DIR/all_y_courses.json" 2>/dev/null | awk '{sum+=$1} END {print sum}')
total_courses_with_y=$(wc -l < "$TEMP_DIR/all_y_courses.json")
total_all_courses=$(wc -l < "$TEMP_DIR/all_courses.json")

if [ "$total_courses_with_y" -gt 0 ]; then
    avg_y_per_course=$(echo "scale=2; $total_y_grades / $total_courses_with_y" | bc)
    pct_courses=$(echo "scale=2; ($total_courses_with_y / $total_all_courses) * 100" | bc)
else
    avg_y_per_course="0.00"
    pct_courses="0.00"
fi

echo "Total Y grades across all quarters: $total_y_grades" | tee -a "$OUTPUT_FILE"
echo "Total courses with Y grades: $total_courses_with_y" | tee -a "$OUTPUT_FILE"
echo "Total courses (all): $total_all_courses" | tee -a "$OUTPUT_FILE"
echo "Percentage of courses with Y grades: ${pct_courses}%" | tee -a "$OUTPUT_FILE"
echo "Average Y grades per course (with Y>0): $avg_y_per_course" | tee -a "$OUTPUT_FILE"

echo ""
echo "7. QUARTERS ANALYZED" | tee -a "$OUTPUT_FILE"
echo "====================" | tee -a "$OUTPUT_FILE"
jq -r '.quarter' "$TEMP_DIR/all_courses.json" 2>/dev/null | sort -u | tee -a "$OUTPUT_FILE"

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "=================================="
echo "Analysis complete!"
echo "Full report saved to: $OUTPUT_FILE"
echo "=================================="
