#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

VARS='${PERSISTANT_PATH} ${POSTGRES_USER} ${POSTGRES_PASSWORD} ${OWNCLOUD_ADMIN_USERNAME} ${OWNCLOUD_ADMIN_PASSWORD} ${N8N_ENCRYPTION_KEY} ${BESZEL_KEY} ${TS_AUTHKEY} ${GRAFANA_ADMIN_USER} ${GRAFANA_ADMIN_PASSWORD} ${LINKDING_SUPERUSER_NAME} ${LINKDING_SUPERUSER_PASSWORD} ${OLLAMA_WEBUI_SECRET_KEY} ${PGADMIN_DEFAULT_EMAIL} ${PGADMIN_DEFAULT_PASSWORD} ${DEV_SSH_PUBLIC_KEY}'

usage() {
    echo "Usage: $0 [all|<pod-yaml-file>]"
    echo "  all or no arg: apply all *.yaml in $SCRIPT_DIR"
    echo "  file path     : apply a single manifest"
}

if ! command -v kubectl >/dev/null 2>&1; then
    echo "Error: kubectl is not installed or not in PATH"
    exit 1
fi

ENV_FILE="$(dirname "$0")/.env"
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

delete_pods() {
    local tmp_file="$1"
    local pod_names
    pod_names=$(kubectl get -f "$tmp_file" --no-headers -o custom-columns=":metadata.name,:kind" 2>/dev/null | awk '$2=="Pod" {print $1}')
    for pod in $pod_names; do
        if kubectl get pod "$pod" &>/dev/null; then
            echo "Deleting pod $pod"
            kubectl delete pod "$pod" --wait=true 2>/dev/null || true
        fi
    done
}

apply_manifest() {
    local yaml_file="$1"
    local tmp_file

    if [ ! -f "$yaml_file" ]; then
        echo "Error: $yaml_file not found"
        exit 1
    fi

    tmp_file="$(mktemp)"
    envsubst "$VARS" < "$yaml_file" > "$tmp_file"
    delete_pods "$tmp_file"
    echo "Applying $yaml_file"
    kubectl apply -f "$tmp_file"
    rm -f "$tmp_file"
}

TARGET="${1:-all}"

if [ "$TARGET" = "all" ]; then
    shopt -s nullglob
    files=("$SCRIPT_DIR"/*.yaml)
    shopt -u nullglob

    if [ ${#files[@]} -eq 0 ]; then
        echo "No YAML files found in $SCRIPT_DIR"
        exit 1
    fi

    for f in "${files[@]}"; do
        apply_manifest "$f"
    done
elif [ "$TARGET" = "-h" ] || [ "$TARGET" = "--help" ]; then
    usage
else
    apply_manifest "$TARGET"
fi