#!/bin/bash
set -e
source .env
export NTFY_DOMAIN NTFY_USER NTFY_PASSWORD NTFY_ALERT_TOPIC NTFY_TOKEN
envsubst < alertmanager/alertmanager.yml.tmpl > alertmanager/alertmanager.yml
echo "alertmanager.yml generated"
