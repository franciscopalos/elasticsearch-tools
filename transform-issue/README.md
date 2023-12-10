# Tools to reproduce issue with Transform in ES 7.17.4
### Francisco Manuel Palos Barcos (fmpalos)


---

## Overview

Brand-generator.sh script create 2 indexes and populate them with data. Both indexes are the same data with different mappings.

First index was data with older timestamp (current date minus 2 days) and multifield data ( text and keyword fields)

Second index have data with the current timestamp but without multifield data (only keyword)

Once we have created both indexes, we have created a transform with the following content:

```json

{
    "source": {
        "index": "stock-shop-car",
        "query": {
            "range": {
                "timestamp": {
                    "gte": "now/d"
                }
            }
        }
    },
    "dest": {
        "index": "stock-aggregated"
    },
    "frequency": "1m",
    "sync": {
        "time": {
            "field": "timestamp",
            "delay": "60s"
        }
    },
    "pivot": {
        "group_by": {
            "timestamp": {
                "date_histogram": {
                    "field": "timestamp",
                    "fixed_interval": "5m"
                }
            }
        },
        "aggregations": {
            "current-stock": {
                "terms": {
                    "field": "brand"
                }
            }
        }
    }
}
```

Script create this transform and start it. 
When transform has been started, if you get _stats query, system will respond:

```

	
task encountered irrecoverable failure: Failed to execute phase [query], Partial shards failure; shardFailures {[SqhJvQKFTyWnOFqSu6Fq7A][stock-cars-000001][0]: RemoteTransportException[[es02][172.18.0.2:9300][indices:data/read/search[phase/query]]]; nested: IllegalArgumentException[Text fields are not optimised for operations that require per-document field data like aggregations and sorting, so these operations are disabled by default. Please use a keyword field instead. Alternatively, set fielddata=true on [brand] in order to load field data by uninverting the inverted index. Note that this can use significant memory.]; }; [Text fields are not optimised for operations that require per-document field data like aggregations and sorting, so these operations are disabled by default. Please use a keyword field instead. Alternatively, set fielddata=true on [brand] in order to load field data by uninverting the inverted index. Note that this can use significant memory.]; nested: IllegalArgumentException[Text fields are not optimised for operations that require per-document field data like aggregations and sorting, so these operations are disabled by default. Please use a keyword field instead. Alternatively, set fielddata=true on [brand] in order to load field data by uninverting the inverted index. Note that this can use significant memory.];; java.lang.IllegalArgumentException: Text fields are not optimised for operations that require per-document field data like aggregations and sorting, so these operations are disabled by default. Please use a keyword field instead. Alternatively, set fielddata=true on [brand] in order to load field data by uninverting the inverted index. Note that this can use significant memory.

```


## Pre-requisites

You need to have a local server listening in localhost:9200 without security.

## Steps to reproduce.

1. Start an elastic local server in 7.17 version listening on port 9200 
2. Execute ` sh brand-generator.sh` file.
3. Get `curl -XGET "http://localhost:9200/_transform/stock-aggregated/_stats"`
4. You will receive the following error:
```json
{
  "count" : 1,
  "transforms" : [
    {
      "id" : "stock-aggregated",
      "state" : "failed",
      "reason" : "task encountered irrecoverable failure: Failed to execute phase [query], Partial shards failure; shardFailures {[SqhJvQKFTyWnOFqSu6Fq7A][stock-cars-000001][0]: RemoteTransportException[[es02][172.18.0.2:9300][indices:data/read/search[phase/query]]]; nested: IllegalArgumentException[Text fields are not optimised for operations that require per-document field data like aggregations and sorting, so these operations are disabled by default. Please use a keyword field instead. Alternatively, set fielddata=true on [brand] in order to load field data by uninverting the inverted index. Note that this can use significant memory.]; }; [Text fields are not optimised for operations that require per-document field data like aggregations and sorting, so these operations are disabled by default. Please use a keyword field instead. Alternatively, set fielddata=true on [brand] in order to load field data by uninverting the inverted index. Note that this can use significant memory.]; nested: IllegalArgumentException[Text fields are not optimised for operations that require per-document field data like aggregations and sorting, so these operations are disabled by default. Please use a keyword field instead. Alternatively, set fielddata=true on [brand] in order to load field data by uninverting the inverted index. Note that this can use significant memory.];; java.lang.IllegalArgumentException: Text fields are not optimised for operations that require per-document field data like aggregations and sorting, so these operations are disabled by default. Please use a keyword field instead. Alternatively, set fielddata=true on [brand] in order to load field data by uninverting the inverted index. Note that this can use significant memory.",
      "node" : {
        "id" : "9EJYlkwaSd6hMnu0GxO3mw",
        "name" : "es01",
        "ephemeral_id" : "I6HD4JAbTMiEUwsA2W4Nww",
        "transport_address" : "172.18.0.3:9300",
        "attributes" : { }
      },
      "stats" : {
        "pages_processed" : 0,
        "documents_processed" : 0,
        "documents_indexed" : 0,
        "documents_deleted" : 0,
        "trigger_count" : 1,
        "index_time_in_ms" : 0,
        "index_total" : 0,
        "index_failures" : 0,
        "search_time_in_ms" : 0,
        "search_total" : 0,
        "search_failures" : 1,
        "processing_time_in_ms" : 0,
        "processing_total" : 0,
        "delete_time_in_ms" : 0,
        "exponential_avg_checkpoint_duration_ms" : 0.0,
        "exponential_avg_documents_indexed" : 0.0,
        "exponential_avg_documents_processed" : 0.0
      },
      "checkpointing" : {
        "last" : {
          "checkpoint" : 0
        },
        "next" : {
          "checkpoint" : 1,
          "checkpoint_progress" : {
            "docs_remaining" : 0,
            "total_docs" : 0,
            "percent_complete" : 100.0,
            "docs_indexed" : 0,
            "docs_processed" : 0
          },
          "timestamp_millis" : 1702211358077,
          "time_upper_bound_millis" : 1702211100000
        },
        "operations_behind" : 2000,
        "changes_last_detected_at" : 1702211358074,
        "last_search_time" : 1702211358074
      }
    }
  ]
}

```
