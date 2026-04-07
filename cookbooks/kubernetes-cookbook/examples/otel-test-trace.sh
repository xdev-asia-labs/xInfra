#!/bin/bash
# OpenTelemetry Test Trace Generator
# This script sends test traces to OTel Collector to verify the tracing pipeline

set -e

# Configuration
OTEL_COLLECTOR_HOST="${OTEL_COLLECTOR_HOST:-172.23.202.22}"
OTEL_HTTP_PORT="${OTEL_HTTP_PORT:-4318}"
SERVICE_NAME="${SERVICE_NAME:-test-service}"
NUM_TRACES="${NUM_TRACES:-5}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}OpenTelemetry Test Trace Generator${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "Configuration:"
echo "  OTel Collector: http://${OTEL_COLLECTOR_HOST}:${OTEL_HTTP_PORT}"
echo "  Service Name:   ${SERVICE_NAME}"
echo "  Number of Traces: ${NUM_TRACES}"
echo ""

# Function to generate random trace ID (32 hex chars)
generate_trace_id() {
    openssl rand -hex 16
}

# Function to generate random span ID (16 hex chars)
generate_span_id() {
    openssl rand -hex 8
}

# Function to get current time in nanoseconds
get_nano_time() {
    # Current time in nanoseconds since epoch
    echo $(( $(date +%s) * 1000000000 + $(date +%N) ))
}

# Function to send a trace with multiple spans
send_trace() {
    local trace_id=$(generate_trace_id)
    local root_span_id=$(generate_span_id)
    local child_span_id=$(generate_span_id)
    
    local start_time=$(get_nano_time)
    local end_time=$(( start_time + 1000000000 ))  # 1 second duration
    local child_end_time=$(( start_time + 500000000 ))  # 500ms duration
    
    local payload=$(cat <<EOF
{
  "resourceSpans": [{
    "resource": {
      "attributes": [
        {"key": "service.name", "value": {"stringValue": "${SERVICE_NAME}"}},
        {"key": "service.version", "value": {"stringValue": "1.0.0"}},
        {"key": "deployment.environment", "value": {"stringValue": "test"}},
        {"key": "telemetry.sdk.name", "value": {"stringValue": "opentelemetry"}},
        {"key": "telemetry.sdk.language", "value": {"stringValue": "shell"}},
        {"key": "telemetry.sdk.version", "value": {"stringValue": "1.0.0"}}
      ]
    },
    "scopeSpans": [{
      "scope": {
        "name": "test-trace-generator",
        "version": "1.0.0"
      },
      "spans": [
        {
          "traceId": "${trace_id}",
          "spanId": "${root_span_id}",
          "name": "HTTP GET /api/users",
          "kind": 2,
          "startTimeUnixNano": "${start_time}",
          "endTimeUnixNano": "${end_time}",
          "attributes": [
            {"key": "http.method", "value": {"stringValue": "GET"}},
            {"key": "http.url", "value": {"stringValue": "http://example.com/api/users"}},
            {"key": "http.status_code", "value": {"intValue": 200}},
            {"key": "http.route", "value": {"stringValue": "/api/users"}},
            {"key": "http.target", "value": {"stringValue": "/api/users?page=1"}},
            {"key": "net.host.name", "value": {"stringValue": "example.com"}},
            {"key": "net.host.port", "value": {"intValue": 80}}
          ],
          "status": {
            "code": 1
          }
        },
        {
          "traceId": "${trace_id}",
          "spanId": "${child_span_id}",
          "parentSpanId": "${root_span_id}",
          "name": "SELECT users FROM database",
          "kind": 3,
          "startTimeUnixNano": "${start_time}",
          "endTimeUnixNano": "${child_end_time}",
          "attributes": [
            {"key": "db.system", "value": {"stringValue": "postgresql"}},
            {"key": "db.name", "value": {"stringValue": "app_db"}},
            {"key": "db.statement", "value": {"stringValue": "SELECT * FROM users WHERE id = ?"}},
            {"key": "db.operation", "value": {"stringValue": "SELECT"}},
            {"key": "db.sql.table", "value": {"stringValue": "users"}},
            {"key": "net.peer.name", "value": {"stringValue": "postgres.default.svc.cluster.local"}},
            {"key": "net.peer.port", "value": {"intValue": 5432}}
          ],
          "status": {
            "code": 1
          }
        }
      ]
    }]
  }]
}
EOF
    )
    
    echo -ne "Sending trace ${1}/${NUM_TRACES} [traceId: ${trace_id}]... "
    
    local response=$(curl -s -w "\n%{http_code}" -X POST \
        "http://${OTEL_COLLECTOR_HOST}:${OTEL_HTTP_PORT}/v1/traces" \
        -H "Content-Type: application/json" \
        -d "${payload}")
    
    local http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" == "200" ] || [ "$http_code" == "202" ]; then
        echo -e "${GREEN}✓ Success (HTTP ${http_code})${NC}"
        echo "    TraceID: ${trace_id}"
        return 0
    else
        echo -e "${RED}✗ Failed (HTTP ${http_code})${NC}"
        echo "$response" | head -n-1
        return 1
    fi
}

# Send multiple traces
success_count=0
failed_count=0

for i in $(seq 1 $NUM_TRACES); do
    if send_trace $i; then
        success_count=$((success_count + 1))
    else
        failed_count=$((failed_count + 1))
    fi
    
    # Small delay between traces
    sleep 0.5
done

echo ""
echo -e "${YELLOW}========================================${NC}"
echo "Results:"
echo -e "  ${GREEN}Success: ${success_count}${NC}"
echo -e "  ${RED}Failed:  ${failed_count}${NC}"
echo ""

# Verification steps
echo "Verification steps:"
echo ""
echo "1. Check traces in Tempo:"
echo "   curl -s \"http://${OTEL_COLLECTOR_HOST}:3200/api/search?tags=service.name=${SERVICE_NAME}&limit=10\" | jq"
echo ""
echo "2. View traces in Grafana Explore:"
echo "   http://${OTEL_COLLECTOR_HOST}:3000/explore"
echo "   - Select Tempo datasource"
echo "   - Query: {service.name=\"${SERVICE_NAME}\"}"
echo ""
echo "3. View service graph:"
echo "   http://${OTEL_COLLECTOR_HOST}:3000/d/service-map/"
echo ""
echo "4. Check service graph metrics (wait 1-2 minutes):"
echo "   curl -s \"http://${OTEL_COLLECTOR_HOST}:9090/api/v1/query?query=traces_service_graph_request_total{server=\\\"${SERVICE_NAME}\\\"}\" | jq"
echo ""

if [ $success_count -gt 0 ]; then
    echo -e "${GREEN}✓ Test traces sent successfully!${NC}"
    exit 0
else
    echo -e "${RED}✗ All traces failed to send${NC}"
    exit 1
fi
