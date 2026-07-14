#!/bin/bash
set -e

CONF_FILE="nginx/nginx.conf"

echo "Checking if $CONF_FILE exists..."
if [ ! -f "$CONF_FILE" ]; then
    echo "Error: $CONF_FILE does not exist"
    exit 1
fi

echo "Verifying file content..."
# Check for key blocks and directives
grep -q "listen 80;" "$CONF_FILE"
grep -q "server_name _;" "$CONF_FILE"
grep -q "location = /" "$CONF_FILE"
grep -q "try_files /index.html =404;" "$CONF_FILE"
grep -q "location / " "$CONF_FILE"
grep -q "try_files \$uri.html @engine;" "$CONF_FILE"
grep -q "location @engine" "$CONF_FILE"
grep -q "proxy_pass http://engine:8000;" "$CONF_FILE"
grep -q "proxy_read_timeout 300s;" "$CONF_FILE"
grep -q "proxy_send_timeout 300s;" "$CONF_FILE"

echo "Content verification passed!"

# If docker is available and running, run the docker-based validation
if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
    echo "Docker is available. Running syntax check..."
    docker run --rm -v "$(pwd)/nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro" nginx:1.27-alpine nginx -t
    echo "Docker syntax check passed!"
else
    echo "Warning: Docker is not installed or running. Skipping docker-based validation."
fi

exit 0
