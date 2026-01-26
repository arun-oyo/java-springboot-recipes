#!/bin/bash

# Define paths
CLASS_PATH="./src/main/java"
TEST_PATH="./src/test/java"

grep -rl "import com.mongodb.DBCollection" "$CLASS_PATH" "$TEST_PATH" | while read -r file; do
    sed -i '' 's/import com.mongodb.DBCollection;/import com.mongodb.client.MongoCollection;/g' "$file"
    sed -i '' 's/import com.mongodb.DBCursor;/import com.mongodb.client.MongoCursor;/g' "$file"
    sed -i '' 's/import com.mongodb.DBObject;/import org.bson.Document;/g' "$file"
    sed -i '' 's/import com.mongodb.BasicDBObject;/import org.bson.Document;/g' "$file"

    sed -i '' -E 's/(^|[^A-Za-z0-9_$])DBCollection([^A-Za-z0-9_$]|$)/\1MongoCollection<Document>\2/g' "$file"
    sed -i '' -E 's/(^|[^A-Za-z0-9_$])DBCursor([^A-Za-z0-9_$]|$)/\1MongoCursor<Document>\2/g' "$file"
    sed -i '' -E 's/(^|[^A-Za-z0-9_$])BasicDBObject([^A-Za-z0-9_$]|$)/\1Document\2/g' "$file"
    sed -i '' -E 's/(^|[^A-Za-z0-9_$])DBObject([^A-Za-z0-9_$]|$)/\1Document\2/g' "$file"
done
