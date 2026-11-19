#!/bin/bash
# Based on OSCAR-Hub crates/simple-test/script.sh; marker is test-only.
FILE_NAME=`basename "$INPUT_FILE_PATH" | cut -d. -f1`
OUTPUT_FILE="$TMP_OUTPUT_DIR/$FILE_NAME-out.txt"

cat "$INPUT_FILE_PATH" > "$OUTPUT_FILE"
echo "This is debug message"
WORD_COUNT=$(wc -w < "$INPUT_FILE_PATH")
CHAR_COUNT=$(wc -m < "$INPUT_FILE_PATH")
echo "File $FILE_NAME was processed. Output saved in: $OUTPUT_FILE"
echo "\nAnalysis:" >> "$OUTPUT_FILE"
echo "Words: $WORD_COUNT" >> "$OUTPUT_FILE"
echo "Characters: $CHAR_COUNT" >> "$OUTPUT_FILE"
echo __MARKER__
