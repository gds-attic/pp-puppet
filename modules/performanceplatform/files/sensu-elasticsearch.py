#!/usr/bin/env python
# encoding: utf-8

import datetime
import json
import requests


JSON_REQUEST = {
  "query": {
    "filtered": {
      "query": {
        "bool": {
          "should": [
            {
              "query_string": {
                "query": "*"
              }
            }
          ]
        }
      },
      "filter": {
        "bool": {
          "must": [
            {
              "match_all": {

              }
            },
            {
              "range": {
                "@timestamp": {
                  "from": "now-1h",
                  "to": "now"
                }
              }
            },
            {
              "fquery": {
                "query": {
                  "field": {
                    "@fields.levelname": {
                      "query": "\"ERROR\""
                    }
                  }
                },
                "_cache": True
              }
            },
            {
              "bool": {
                "must": [
                  {
                    "match_all": {

                    }
                  }
                ]
              }
            }
          ]
        }
      }
    }
  },
  "highlight": {
    "fields": {

    },
    "fragment_size": 2147483647,
    "pre_tags": [
      "@start-highlight@"
    ],
    "post_tags": [
      "@end-highlight@"
    ]
  },
  "size": 500,
  "sort": [
    {
      "@timestamp": {
        "order": "desc"
      }
    }
  ]
}


def main():
    now = datetime.datetime.now().date()
    es_host = 'elasticsearch:9200'
    es_index = 'logstash-{year:04}.{month:02}.{day:02}'.format(
        year=now.year, month=now.month, day=now.day)

    response = requests.post(
        'http://{}/{}/_search'.format(es_host, es_index),
        headers={'Content-Type': 'application/json'},
        data=json.dumps(JSON_REQUEST))
    response.raise_for_status()
    response_data = json.loads(response.content)
    from pprint import pprint
    hits = response_data['hits']['hits']
    print("{} log matches".format(len(hits)))
    for i, hit in enumerate(hits):
        print("--- Log message #{} --- ".format(i + 1))
        pprint(hits[0]['_source'])

    return 2 if len(hits) > 0 else 0

if __name__ == '__main__':
    main()
