#!/bin/bash

# Define paths
CLASS_PATH="./src/main/java"
TEST_PATH="./src/test/java"

grep -rl "import com.mongodb.DBCollection" "$CLASS_PATH"  | while read -r file; do
    sed -i '' 's/import com.mongodb.DBCollection;/import com.mongodb.client.MongoCollection;/g' "$file"
    sed -i '' 's/import com.mongodb.DBCursor;/import com.mongodb.client.MongoCursor;/g' "$file"
    sed -i '' 's/import com.mongodb.DBObject;/import org.bson.Document;/g' "$file"
    sed -i '' 's/import com.mongodb.BasicDBObject;/import org.bson.Document;/g' "$file"

    sed -i '' 's/DBCollection/MongoCollection<Document>/g' "$file"
    sed -i '' 's/DBCursor/MongoCursor<Document>/g' "$file"
    sed -i '' 's/BasicDBObject/Document/g' "$file"
    sed -i '' 's/DBObject/Document/g' "$file"
done