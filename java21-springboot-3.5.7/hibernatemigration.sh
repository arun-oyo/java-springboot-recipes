#!/bin/bash

# Define versions to update to
JAVA_VERSION=21
SPRING_BOOT_VERSION=3.5.7
CLASS_PATH="./src/main/java"
PROPERTIES_PATH="./src/main/resources"
TEST_PATH="./src/test/java"


grep -rl "import org.hibernate.annotations.TypeDef" "$CLASS_PATH" | while read -r file; do
    sed -i '' '/import org.hibernate.annotations.TypeDef/d' $file
    sed -i '' '/import org.hibernate.annotations.TypeDefs/d' $file

    typedefline=$(awk '
        BEGIN { in_typedef = 0 }
        /@TypeDef\(/ { in_typedef = 1; line = $0 }  # Start collecting lines
        in_typedef && !/\)/ { line = line " " $0 }  # Concatenate lines
        in_typedef && /\)/ {                        # End when closing parenthesis is found
            line = line " " $0
            gsub(/[[:space:]]+/, " ", line)         # Replace multiple spaces with a single space
            print line                              # Print the single-line result
            in_typedef = 0
        }
    ' "$file" | tr '\n' ' ')

    names=$(echo "$typedefline" | ggrep -Po 'name\s*=\s*"\K[^"]*')
    types=$(echo "$typedefline" | ggrep -Po 'typeClass\s*=\s*\K[^,)]+\.class')

    IFS=$'\n' read -r -d '' -a nameArray <<< "$names"
    IFS=$'\n' read -r -d '' -a typeArray <<< "$types"

    for ((i=0; i<${#nameArray[@]}; i++)); do
        sed -i '' -E "s/type[[:space:]]*=[[:space:]]*\"${nameArray[i]}\"/${typeArray[i]}/g" "$file"
    done

    awk '
        /@TypeDefs/ { 
            start = NR;                                # Record the starting line number
            paren_count += gsub(/\(/, "(") - gsub(/\)/, ")");  # Adjust parentheses count
            if (paren_count == 0) {                   # Single-line case
                print start "," start;                # Output the single-line range
                exit;
            }
            next;
        }
        start && paren_count > 0 {
            paren_count += gsub(/\(/, "(") - gsub(/\)/, ")");  # Continue tracking parentheses
            if (paren_count == 0) {                   # Multiline case when balanced
                print start "," NR;                   # Output the range
                exit;
            }
        }
        ' "$file" | while read range; do
            sed -i '' "${range}d" $file
        done

    awk '
        /@TypeDef/ { 
            start = NR;                                # Record the starting line number
            paren_count += gsub(/\(/, "(") - gsub(/\)/, ")");  # Adjust parentheses count
            if (paren_count == 0) {                   # Single-line case
                print start "," start;                # Output the single-line range
                exit;
            }
            next;
        }
        start && paren_count > 0 {
            paren_count += gsub(/\(/, "(") - gsub(/\)/, ")");  # Continue tracking parentheses
            if (paren_count == 0) {                   # Multiline case when balanced
                print start "," NR;                   # Output the range
                exit;
            }
        }
        ' "$file" | while read range; do
            sed -i '' "${range}d" $file
        done
done