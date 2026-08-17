#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 https://service.example.com" >&2
  exit 2
fi

base_url=${1%/}

curl --fail --silent --show-error --max-time 10 "$base_url/health/live" >/dev/null
curl --fail --silent --show-error --max-time 10 "$base_url/health/ready" >/dev/null
curl --fail --silent --show-error --max-time 10 "$base_url/" >/dev/null

echo "Smoke test passed for $base_url"
