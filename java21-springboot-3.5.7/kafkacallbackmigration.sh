#!/bin/bash

# Kafka Producer Callback Migration Script
# Migrates ListenableFuture.addCallback() to CompletableFuture.whenComplete()

CLASS_PATH="./src/main/java"
TEST_PATH="./src/test/java"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

echo "Starting Kafka producer callback migration..."

# Import changes - ListenableFuture to CompletableFuture
echo "Changing ListenableFuture imports to CompletableFuture..."
grep -rl "org.springframework.util.concurrent.ListenableFuture" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/import org.springframework.util.concurrent.ListenableFuture;/import java.util.concurrent.CompletableFuture;/g' "$file"
    sed -i '' '/import org\.springframework\.util\.concurrent\.ListenableFutureCallback/d' "$file"


    while grep -q "\.addCallback" "$file"; do
        echo "File $(basename "$file") contains .addCallback calls."
        sh "$SCRIPT_DIR/kafka-callback-migration.sh" "$file"
    done
done

echo ""
echo "Kafka callback migration completed!"
echo ""
echo "Changes applied:"
echo "✅ ListenableFuture → CompletableFuture imports"
echo "✅ Removed ListenableFutureCallback imports"
echo "✅ .addCallback(...) → .whenComplete((result, ex) -> {...})"
echo "✅ onSuccess(result) → if (ex == null) {...}"
echo "✅ onFailure(ex) → } else {...}"
echo ""
