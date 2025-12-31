#!/bin/bash

# Define versions to update to
JAVA_VERSION=21
SPRING_BOOT_VERSION=3.5.7
CLASS_PATH="./src/main/java"
TEST_PATH="./src/test/java"

# Add @Serial annotation over serialVersionUID declarations
echo "Adding @Serial annotation to serialVersionUID fields..."

find "$CLASS_PATH" "$TEST_PATH" -type f -name "*.java" 2>/dev/null | while read -r file; do
  if grep -q "serialVersionUID" "$file"; then
    echo "Processing: $(basename "$file")"
    
    # Add @Serial annotation before serialVersionUID if not already present
    awk '
    /private[[:space:]]+static[[:space:]]+final[[:space:]]+long[[:space:]]+serialVersionUID/ {
      if (prev !~ /@Serial/) {
        match($0, /^[[:space:]]*/)
        indent = substr($0, RSTART, RLENGTH)
        print indent "@Serial"
      }
    }
    { print; prev = $0 }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    
    # Add import java.io.Serial; as the 3rd line if not already present
    if grep -q "@Serial" "$file" && ! grep -q "^import java.io.Serial;" "$file"; then
      sed -i '' '3i\
import java.io.Serial;
' "$file"
    fi
  fi
done

echo "@Serial annotation migration completed"
