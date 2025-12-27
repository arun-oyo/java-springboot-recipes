#!/bin/bash

# Define versions to update to
JAVA_VERSION=21
SPRING_BOOT_VERSION=3.5.7
CLASS_PATH="./src/main/java"
PROPERTIES_PATH="./src/main/resources"
TEST_PATH="./src/test/java"

grep -rl "ApiModelProperty" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/import[[:space:]\n]*io.swagger.annotations.ApiModelProperty/import io.swagger.v3.oas.annotations.media.Schema/g' "$file"
    
    while :; do
        # Extract the annotation preserving newlines and structure
        line=$(ggrep -Pzo '@ApiModelProperty\((?:[^()"]|"(?:[^"\\]|\\.)*"|(?:\([^)]*\)))*\)' "$file" | tr '\0' '\n' | head -1)
        
        if [ -z "$line" ]; then
            break
        fi
        
        # Transform the annotation while preserving all attributes
        transformed=$(echo "$line" | \
            # First replace ApiModelProperty with Schema
            sed -E 's/@ApiModelProperty/@Schema/' | \
            # Replace 'value' with 'description' (only the attribute name)
            sed -E 's/\bvalue[[:space:]]*=/description =/g' | \
            # Replace 'notes' with 'description'
            sed -E 's/\bnotes[[:space:]]*=/description =/g' | \
            # Handle case where there's only a string without attribute name: @Schema("text") -> @Schema(description = "text")
            sed -E 's/@Schema\([[:space:]]*"/@Schema(description = "/g' | \
            # Normalize spacing around = signs for consistency
            perl -pe 's/\s*(description|example|required|allowableValues|hidden|dataType)\s*=\s*/\1 = /g')
        
        # Find the line range for this annotation
        awk '
        /@ApiModelProperty/ {start=NR; paren_count=0; found_start=0}
        start && !found_start {
            for (i=1; i<=length($0); i++) {
                c = substr($0, i, 1);
                if (c == "(") paren_count++;
                if (c == ")") paren_count--;
                if (paren_count == 0 && c == ")") {
                    print start "," NR;
                    exit;
                }
            }
            if (paren_count == 0) found_start=1;
        }
        ' "$file" | while read range; do
            if [ -n "$range" ]; then
                start_line=$(echo "$range" | cut -d',' -f1)
                end_line=$(echo "$range" | cut -d',' -f2)
                
                # Get the indentation from the original line
                indent=$(sed -n "${start_line}p" "$file" | sed -E 's/^([[:space:]]*).*$/\1/')
                
                # Create a temp file with the transformed annotation
                temp_file=$(mktemp)
                echo "$transformed" | sed "s/^/${indent}/" > "$temp_file"
                
                # Delete the old annotation lines
                sed -i '' "${start_line},${end_line}d" "$file"
                
                # Insert the transformed annotation at the correct position
                # We need to insert at start_line-1 and then append
                if [ "$start_line" -eq 1 ]; then
                    # Special case for first line
                    cat "$temp_file" "$file" > "${temp_file}.2"
                    mv "${temp_file}.2" "$file"
                else
                    # Insert after line start_line-1
                    sed -i '' "$((start_line-1))r ${temp_file}" "$file"
                fi
                
                rm -f "$temp_file"
            fi
        done
    done
    echo "Processed file: $file"
done

# Transform @ApiModel annotations to @Schema
grep -rl "ApiModel" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/import[[:space:]\n]*io.swagger.annotations.ApiModel/import io.swagger.v3.oas.annotations.media.Schema/g' "$file"
    
    while :; do
        # Extract the @ApiModel annotation
        line=$(ggrep -Pzo '@ApiModel\((?:[^()"]|"(?:[^"\\]|\\.)*"|(?:\([^)]*\)))*\)' "$file" | tr '\0' '\n' | head -1)
        
        if [ -z "$line" ]; then
            break
        fi
        
        # Transform the annotation
        transformed=$(echo "$line" | \
            # Replace ApiModel with Schema
            sed -E 's/@ApiModel/@Schema/' | \
            # Replace 'value' with 'description'
            sed -E 's/\bvalue[[:space:]]*=/description =/g' | \
            # Handle case where there's only a string: @Schema("text") -> @Schema(description = "text")
            sed -E 's/@Schema\([[:space:]]*"/@Schema(description = "/g' | \
            # Normalize spacing
            perl -pe 's/\s*(description|name)\s*=\s*/\1 = /g')
        
        # Find the line range for this annotation
        awk '
        /@ApiModel/ {start=NR; paren_count=0; found_start=0}
        start && !found_start {
            for (i=1; i<=length($0); i++) {
                c = substr($0, i, 1);
                if (c == "(") paren_count++;
                if (c == ")") paren_count--;
                if (paren_count == 0 && c == ")") {
                    print start "," NR;
                    exit;
                }
            }
            if (paren_count == 0) found_start=1;
        }
        ' "$file" | while read range; do
            if [ -n "$range" ]; then
                start_line=$(echo "$range" | cut -d',' -f1)
                end_line=$(echo "$range" | cut -d',' -f2)
                
                # Get the indentation from the original line
                indent=$(sed -n "${start_line}p" "$file" | sed -E 's/^([[:space:]]*).*$/\1/')
                
                # Create a temp file with the transformed annotation
                temp_file=$(mktemp)
                echo "$transformed" | sed "s/^/${indent}/" > "$temp_file"
                
                # Delete the old annotation lines
                sed -i '' "${start_line},${end_line}d" "$file"
                
                # Insert the transformed annotation at the correct position
                if [ "$start_line" -eq 1 ]; then
                    # Special case for first line
                    cat "$temp_file" "$file" > "${temp_file}.2"
                    mv "${temp_file}.2" "$file"
                else
                    # Insert after line start_line-1
                    sed -i '' "$((start_line-1))r ${temp_file}" "$file"
                fi
                
                rm -f "$temp_file"
            fi
        done
    done
    echo "Processed @ApiModel in file: $file"
done

# Transform @ApiOperation annotations to @Operation
grep -rl "ApiOperation" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/import[[:space:]\n]*io.swagger.annotations.ApiOperation/import io.swagger.v3.oas.annotations.Operation/g' "$file"
    
    while :; do
        # Extract the @ApiOperation annotation
        line=$(ggrep -Pzo '@ApiOperation\((?:[^()"]|"(?:[^"\\]|\\.)*"|(?:\([^)]*\)))*\)' "$file" | tr '\0' '\n' | head -1)
        
        if [ -z "$line" ]; then
            break
        fi
        
        # Transform the annotation
        transformed=$(echo "$line" | \
            # Replace ApiOperation with Operation
            sed -E 's/@ApiOperation/@Operation/' | \
            # Replace 'notes' with 'description'
            sed -E 's/\bnotes[[:space:]]*=/description =/g' | \
            # 'value' becomes 'summary' in Operation
            sed -E 's/\bvalue[[:space:]]*=/summary =/g' | \
            # Handle case where there's only a string: @Operation("text") -> @Operation(summary = "text")
            sed -E 's/@Operation\([[:space:]]*"/@Operation(summary = "/g' | \
            # Normalize spacing
            perl -pe 's/\s*(summary|description|tags|responses|hidden)\s*=\s*/\1 = /g')
        
        # Find the line range for this annotation
        awk '
        /@ApiOperation/ {start=NR; paren_count=0; found_start=0}
        start && !found_start {
            for (i=1; i<=length($0); i++) {
                c = substr($0, i, 1);
                if (c == "(") paren_count++;
                if (c == ")") paren_count--;
                if (paren_count == 0 && c == ")") {
                    print start "," NR;
                    exit;
                }
            }
            if (paren_count == 0) found_start=1;
        }
        ' "$file" | while read range; do
            if [ -n "$range" ]; then
                start_line=$(echo "$range" | cut -d',' -f1)
                end_line=$(echo "$range" | cut -d',' -f2)
                
                # Get the indentation from the original line
                indent=$(sed -n "${start_line}p" "$file" | sed -E 's/^([[:space:]]*).*$/\1/')
                
                # Create a temp file with the transformed annotation
                temp_file=$(mktemp)
                echo "$transformed" | sed "s/^/${indent}/" > "$temp_file"
                
                # Delete the old annotation lines
                sed -i '' "${start_line},${end_line}d" "$file"
                
                # Insert the transformed annotation at the correct position
                if [ "$start_line" -eq 1 ]; then
                    # Special case for first line
                    cat "$temp_file" "$file" > "${temp_file}.2"
                    mv "${temp_file}.2" "$file"
                else
                    # Insert after line start_line-1
                    sed -i '' "$((start_line-1))r ${temp_file}" "$file"
                fi
                
                rm -f "$temp_file"
            fi
        done
    done
    echo "Processed @ApiOperation in file: $file"
done

grep -rl "springfox.documentation" "$CLASS_PATH" | xargs sed -i '' '/springfox.documentation/d'
grep -rl "@EnableSwagger2" "$CLASS_PATH" | xargs sed -i '' '/@EnableSwagger2/d'
