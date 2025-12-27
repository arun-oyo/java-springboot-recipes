#!/bin/bash

# Define versions to update to
JAVA_VERSION=21
SPRING_BOOT_VERSION=3.5.7
CLASS_PATH="./src/main/java"
PROPERTIES_PATH="./src/main/resources"
TEST_PATH="./src/test/java"

grep -rl "com.getsentry.raven.logback.SentryAppender" "PROPERTIES_PATH" | while read -r file; do
    sed -i '' 's/com.getsentry.raven.logback.SentryAppender/io.sentry.logback.SentryAppender/g' "$file"
done
