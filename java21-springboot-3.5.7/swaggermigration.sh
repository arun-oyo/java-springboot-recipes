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
        line=`ggrep -Pzo '@ApiModelProperty\((.|\n)*?\)' $file | tr '\n' ' ' | sed -E 's/value/description/' | sed -E 's/notes/description/' | sed -E 's/ApiModelProperty/Schema/' | sed -E 's/Schema\(\s*"\s*([^"]+)\s*"\s*\)/Schema(description = "\1")/g' | perl -pe 's/\s+/ /g; s/\s*(description|example|required)\s*=\s*/\1 = /g' | cut -d"@" -f 2`

        if [ -z "$line" ]; then
            break
        fi

        line='@'$line$'\n'

        awk '
        /@ApiModelProperty/ {start=NR}
        /\)/ && start {print start "," NR; exit}
        ' $file | while read range; do
            start_line=$(echo $range | cut -d',' -f1)
            sed -i '' "${range}d" $file
            sed -i '' "$((start_line)) i\\
" $file
            sed -i '' "$((start_line)) i\\
    $line
        " $file
        done
    done
    echo "Processed file: $file"
done

grep -rl "springfox.documentation" "$CLASS_PATH" | xargs sed -i '' '/springfox.documentation/d'
grep -rl "@EnableSwagger2" "$CLASS_PATH" | xargs sed -i '' '/@EnableSwagger2/d'
