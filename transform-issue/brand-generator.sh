#!/bin/bash

# This script generates and populates an Elasticsearch index with stock car data.
# It performs the following steps:
# 1. Deletes previous executions
# 2. Creates an ILM (Index Lifecycle Management) policy
# 3. Creates an index template
# 4. Initializes the index
# 5. Generates 1000 random stock car documents
# 6. Performs a bulk insert of the generated documents
# 7. Changes the mapping in the index template
# 8. Performs an index rollover
# 9. Generates another 1000 random stock car documents
# 10. Performs a second bulk insert of the generated documents
# 11. Creates an index template for aggregation
# 12. Creates a transform for aggregating data
# 13. Starts the transform
# 14. Checks the status of the transform
# 15. Removes temporary bulk files

# Function to delete previous executions and reset status
function reset_status() {
  curl -XDELETE "localhost:9200/stock-cars-*" 2>/dev/null
  curl -XDELETE "localhost:9200/_ilm/policy/ilm-stock" 2>/dev/null
  curl -XDELETE "localhost:9200/_index_template/stock-cars" 2>/dev/null
  curl -XDELETE "localhost:9200/_index_template/stock-aggregated" 2>/dev/null
  curl -XDELETE "localhost:9200/_stock-aggregated" 2>/dev/null

  # Check if transform exists
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "localhost:9200/_transform/stock-aggregated")

  if [ "$RESPONSE" -eq 200 ]; then
    echo "Transform exists."
    curl -XPOST "localhost:9200/_transform/stock-aggregated/_stop?force=true" 2>/dev/null
    sleep 5;
    curl -XDELETE "localhost:9200/_transform/stock-aggregated" 2>/dev/null
  else
    echo "Transform does not exist."
  fi
}

# Main function
function main() {
  # Delete previous executions
  reset_status

  # Array of car brands
  MARCAS=("Toyota" "Honda" "Ford" "Chevrolet" "Nissan")

  # Array of car models
  MODELOS=("Corolla" "Civic" "Mustang" "Camaro" "Altima")

  # Create ILM policy
  curl -XPUT "localhost:9200/_ilm/policy/ilm-stock" -H 'Content-Type: application/json' --data-binary "@ilm-stock.json"

  # Create index template
  echo "" > bulk.json
  echo "create template..."
  curl -XPUT "localhost:9200/_index_template/stock-cars" -H 'Content-Type: application/json' --data-binary "@template.json"

  # Initialize index
  curl -XPUT "localhost:9200/stock-cars-000001" -H 'Content-Type: application/json' -d'
  {
    "aliases": {
      "stock-shop-car": {
        "is_write_index": true
      }
    }
  }'

  # Generate 1000 documents
  echo "generating 1000 documents random...";
  for i in {1..1000}
  do
    MARCA=${MARCAS[$RANDOM % ${#MARCAS[@]}]}
    MODELO=${MODELOS[$RANDOM % ${#MODELOS[@]}]}
    TIMESTAMP=$(date --iso-8601=seconds -d "-2 days")
    echo "{ \"index\" : { \"_index\" : \"stock-shop-car\", \"_id\" : \"$i\" } }" >> bulk.json
    echo "{ \"timestamp\" : \"$TIMESTAMP\", \"brand\" : \"$MARCA\", \"model\" : \"$MODELO\" }" >> bulk.json
  done

  # Perform bulk insert
  echo "doing bulk.."
  curl -XPOST "localhost:9200/_bulk?pretty" -H 'Content-Type: application/json' --data-binary "@bulk.json" > /dev/null

  # Change mapping in index template
  echo "change mapping in template"
  curl -XPUT "localhost:9200/_index_template/stock-cars" -H 'Content-Type: application/json' --data-binary "@template_modified.json"

  # Perform index rollover
  echo "Rollover index.."
  curl -XPOST "localhost:9200/stock-shop-car/_rollover"

  # Generate another 1000 documents
  echo "" > second-bulk.json
  echo "generating another 1000 documents random...";
  for i in {1..1000}
  do
    MARCA=${MARCAS[$RANDOM % ${#MARCAS[@]}]}
    MODELO=${MODELOS[$RANDOM % ${#MODELOS[@]}]}
    echo "{ \"index\" : { \"_index\" : \"stock-shop-car\", \"_id\" : \"$i\" } }" >> second-bulk.json
    echo "{ \"timestamp\" : \"$(date --iso-8601=seconds )\", \"brand\" : \"$MARCA\", \"model\" : \"$MODELO\" }" >> second-bulk.json
  done

  # Perform second bulk insert
  curl -XPOST "localhost:9200/_bulk?pretty" -H 'Content-Type: application/json' --data-binary "@second-bulk.json" > /dev/null

  # Create index template for aggregation
  curl -XPUT "localhost:9200/_index_template/stock-aggregated" -H 'Content-Type: application/json' --data-binary "@template_aggregation.json"

  # Create transform for aggregation
  curl -XPUT "localhost:9200/_transform/stock-aggregated" -H 'Content-Type: application/json' --data-binary "@transform-aggregation.json"

  # Start transform
  curl -XPOST "localhost:9200/_transform/stock-aggregated/_start"

  # Check transform status
  curl -XGET "localhost:9200/_transform/stock-aggregated/_stats?pretty"

  # Remove temporary bulk files
  rm bulk.json
  rm second-bulk.json
}

# Call the main function
main