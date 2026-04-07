# OpenTelemetry Examples

This directory contains example configurations and scripts for instrumenting applications with OpenTelemetry distributed tracing.

## Files

### Configuration Examples

- **`otel-java-instrumentation.yaml`** - Complete example of Java/Spring Boot application with OTel Java agent
- **`otel-python-instrumentation.yaml`** - Python FastAPI application with OTel auto-instrumentation
- **`otel-test-trace.sh`** - Shell script to send test traces to verify the tracing pipeline

## Quick Start

### 1. Test Tracing Pipeline

Before instrumenting your applications, verify the tracing pipeline is working:

```bash
# Make the test script executable
chmod +x examples/otel-test-trace.sh

# Send 5 test traces
./examples/otel-test-trace.sh

# Or with custom configuration
OTEL_COLLECTOR_HOST=172.23.202.22 \
SERVICE_NAME=my-test-service \
NUM_TRACES=10 \
./examples/otel-test-trace.sh
```

Expected output:
```
========================================
OpenTelemetry Test Trace Generator
========================================

Sending trace 1/5 [traceId: a1b2c3...] ✓ Success (HTTP 200)
Sending trace 2/5 [traceId: d4e5f6...] ✓ Success (HTTP 200)
...

Results:
  Success: 5
  Failed:  0
```

### 2. Verify Traces in Grafana

After sending test traces:

1. **Explore Traces App**: http://172.23.202.22:3000/a/grafana-exploretraces-app/explore
2. **Classic Explore**: http://172.23.202.22:3000/explore (select Tempo datasource)
3. **Service Map Dashboard**: http://172.23.202.22:3000/d/service-map/

### 3. Instrument Your Java Application

Copy and modify `otel-java-instrumentation.yaml`:

```bash
# Copy example
cp examples/otel-java-instrumentation.yaml k8s/deployments/your-service.yaml

# Edit to match your application
vim k8s/deployments/your-service.yaml
```

Key changes to make:
1. Update `metadata.name` and `metadata.namespace`
2. Change `OTEL_SERVICE_NAME` to your service name
3. Set your container image
4. Update health check paths
5. Adjust resource requests/limits

Apply the deployment:
```bash
kubectl apply -f k8s/deployments/your-service.yaml
```

### 4. Instrument Your Python Application

Use `otel-python-instrumentation.yaml` as a template:

```bash
# Update your Dockerfile with OTel packages
# See comments in otel-python-instrumentation.yaml

# Update requirements.txt with OTel dependencies
# See example in the YAML file

# Build and push new image
docker build -t your-registry/your-app:v2-otel .
docker push your-registry/your-app:v2-otel

# Apply deployment
kubectl apply -f k8s/deployments/your-python-service.yaml
```

## Environment Variables Reference

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `OTEL_SERVICE_NAME` | Service name in traces | `"identity-service"` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTel Collector endpoint | `"http://localhost:4317"` |
| `OTEL_TRACES_EXPORTER` | Trace exporter type | `"otlp"` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OTEL_EXPORTER_OTLP_PROTOCOL` | Protocol (grpc/http) | `"grpc"` |
| `OTEL_TRACES_SAMPLER` | Sampling strategy | `"parentbased_always_on"` |
| `OTEL_TRACES_SAMPLER_ARG` | Sampling ratio (0.0-1.0) | `"1.0"` |
| `OTEL_METRICS_EXPORTER` | Metrics exporter | `"none"` |
| `OTEL_LOGS_EXPORTER` | Logs exporter | `"none"` |
| `OTEL_RESOURCE_ATTRIBUTES` | Resource attributes | `"key=value,..."` |

## Verification Commands

### Check OTel Collector is Running

```bash
# On the application node
ssh -i ~/.ssh/fci root@<node-ip> 'systemctl status otel-collector'

# Check metrics
curl http://<node-ip>:4327/metrics | grep otelcol_receiver_accepted_spans
```

### Check Application Logs

```bash
# Check if OTel agent loaded (Java)
kubectl logs -n <namespace> <pod-name> | grep -i opentelemetry

# Expected output:
# [otel.javaagent 2024-XX-XX XX:XX:XX:XXX] [main] INFO io.opentelemetry.javaagent.tooling.VersionLogger - opentelemetry-javaagent - version: 2.11.0
```

### Query Traces from Tempo

```bash
# Search for traces by service name
curl -s "http://172.23.202.22:3200/api/search?tags=service.name=identity-service&limit=10" | jq

# Get specific trace
curl -s "http://172.23.202.22:3200/api/traces/<trace-id>" | jq
```

### Check Service Graph Metrics

```bash
# Wait 1-2 minutes after traces are sent, then check:
curl -s "http://172.23.202.22:9090/api/v1/query?query=traces_service_graph_request_total" | jq

# Should see metrics like:
# traces_service_graph_request_total{client="service-a", server="service-b"}
```

## Troubleshooting

### No traces showing up

1. **Check OTel Collector logs:**
   ```bash
   ssh -i ~/.ssh/fci root@<node-ip> 'journalctl -u otel-collector -f'
   ```

2. **Verify network connectivity:**
   ```bash
   kubectl exec -it <pod-name> -n <namespace> -- nc -zv localhost 4317
   ```

3. **Check application logs for OTel errors:**
   ```bash
   kubectl logs -n <namespace> <pod-name> | grep -i "otel\|trace\|span"
   ```

4. **Verify Tempo is receiving data:**
   ```bash
   ssh -i ~/.ssh/fci root@172.23.202.22 'curl -s http://localhost:3200/metrics | grep tempo_distributor_spans_received_total'
   ```

### Service graph not showing

1. **Check if metrics generator is working:**
   ```bash
   curl -s http://172.23.202.22:3200/metrics | grep tempo_metrics_generator
   ```

2. **Verify Prometheus is scraping Tempo:**
   ```bash
   curl -s "http://172.23.202.22:9090/api/v1/targets" | jq '.data.activeTargets[] | select(.labels.job=="tempo")'
   ```

3. **Wait 1-2 minutes** - metrics generation has a delay

### High memory usage with Java agent

1. **Reduce sampling rate:**
   ```yaml
   - name: OTEL_TRACES_SAMPLER_ARG
     value: "0.1"  # Sample 10% of traces
   ```

2. **Disable specific instrumentations:**
   ```yaml
   - name: OTEL_INSTRUMENTATION_JDBC_ENABLED
     value: "false"
   ```

3. **Adjust span processor:**
   ```yaml
   - name: OTEL_BSP_MAX_QUEUE_SIZE
     value: "512"
   - name: OTEL_BSP_MAX_EXPORT_BATCH_SIZE
     value: "128"
   ```

## Best Practices

1. **Use meaningful service names** - avoid generic names like "app" or "service"
2. **Add resource attributes** - include namespace, pod name, environment
3. **Sample in production** - don't trace 100% of requests in high-traffic services
4. **Correlate with logs** - add trace_id to log messages
5. **Create custom spans** - for critical business operations
6. **Test locally first** - use the test script before instrumenting apps
7. **Monitor overhead** - track CPU/memory after enabling tracing

## Additional Resources

- [Full Documentation](../docs/tracing-instrumentation.md)
- [OpenTelemetry Java Agent](https://github.com/open-telemetry/opentelemetry-java-instrumentation)
- [OpenTelemetry Python](https://opentelemetry.io/docs/instrumentation/python/)
- [Grafana Tempo Docs](https://grafana.com/docs/tempo/latest/)
- [Service Graph Docs](https://grafana.com/docs/tempo/latest/metrics-generator/service_graphs/)
