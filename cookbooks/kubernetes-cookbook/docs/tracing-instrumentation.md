# OpenTelemetry Tracing Instrumentation Guide

## Overview

This guide explains how to instrument your applications to send distributed traces to Tempo via OpenTelemetry Collector.

## Architecture

```
Application (instrumented)
  └─> OTel Collector (localhost:4317 gRPC / 4318 HTTP)
      └─> Tempo (172.23.202.22:3200)
          └─> Grafana (dashboards, service graph, trace explorer)
          └─> Prometheus (service graph metrics via remote_write)
```

## Prerequisites

- Applications running in Kubernetes cluster
- OTel Collector deployed on each node (already configured via monitoring role)
- Tempo 2.8.3+ running on monitoring server
- Grafana with Tempo datasource configured

## Instrumentation Methods

### 1. Java Applications (Spring Boot, Quarkus, etc.)

#### Option A: Auto-instrumentation with Java Agent (Recommended)

**Step 1:** Add OTel Java agent to your deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: your-service
spec:
  template:
    spec:
      initContainers:
        - name: download-otel-agent
          image: busybox:latest
          command:
            - sh
            - -c
            - |
              wget -O /otel/opentelemetry-javaagent.jar \
                https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v2.11.0/opentelemetry-javaagent.jar
          volumeMounts:
            - name: otel-agent
              mountPath: /otel
      
      containers:
        - name: app
          image: your-image:tag
          env:
            # OpenTelemetry configuration
            - name: OTEL_SERVICE_NAME
              value: "your-service-name"  # Change to your service name
            
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://localhost:4317"  # OTel Collector gRPC endpoint
            
            - name: OTEL_EXPORTER_OTLP_PROTOCOL
              value: "grpc"
            
            - name: OTEL_TRACES_EXPORTER
              value: "otlp"
            
            - name: OTEL_METRICS_EXPORTER
              value: "none"  # Disable metrics export (use Prometheus instead)
            
            - name: OTEL_LOGS_EXPORTER
              value: "none"  # Disable logs export (use Promtail/Loki instead)
            
            - name: OTEL_TRACES_SAMPLER
              value: "parentbased_traceidratio"
            
            - name: OTEL_TRACES_SAMPLER_ARG
              value: "1.0"  # 100% sampling (adjust for production: 0.1 = 10%)
            
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: "deployment.environment=production,k8s.namespace.name=$(NAMESPACE),k8s.pod.name=$(POD_NAME),k8s.node.name=$(NODE_NAME)"
            
            # Pod metadata
            - name: NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            
            # Java agent
            - name: JAVA_TOOL_OPTIONS
              value: "-javaagent:/opt/otel/opentelemetry-javaagent.jar"
          
          volumeMounts:
            - name: otel-agent
              mountPath: /opt/otel
      
      volumes:
        - name: otel-agent
          emptyDir: {}
```

**Supported frameworks (auto-instrumented):**
- Spring Boot (WebMVC, WebFlux)
- Spring Data (JPA, JDBC, MongoDB, Redis)
- Hibernate
- JDBC drivers (PostgreSQL, MySQL, Oracle)
- HTTP clients (OkHttp, Apache HttpClient, RestTemplate)
- Kafka, RabbitMQ
- gRPC
- And 200+ libraries

#### Option B: Manual instrumentation

Add dependency to `pom.xml` (Maven):
```xml
<dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-api</artifactId>
    <version>1.44.1</version>
</dependency>
<dependency>
    <groupId>io.opentelemetry.instrumentation</groupId>
    <artifactId>opentelemetry-spring-boot-starter</artifactId>
    <version>2.11.0-alpha</version>
</dependency>
```

Configure in `application.yml`:
```yaml
otel:
  service:
    name: ${spring.application.name}
  exporter:
    otlp:
      endpoint: http://localhost:4317
  traces:
    exporter: otlp
  metrics:
    exporter: none
  logs:
    exporter: none
```

### 2. .NET Applications (ASP.NET Core)

Add packages:
```bash
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Instrumentation.Http
dotnet add package OpenTelemetry.Exporter.OpenTelemetryProtocol
```

Configure in `Program.cs`:
```csharp
builder.Services.AddOpenTelemetry()
    .WithTracing(tracerProviderBuilder =>
        tracerProviderBuilder
            .AddSource(builder.Environment.ApplicationName)
            .SetResourceBuilder(ResourceBuilder.CreateDefault()
                .AddService(serviceName: builder.Environment.ApplicationName))
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddOtlpExporter(options =>
            {
                options.Endpoint = new Uri("http://localhost:4317");
                options.Protocol = OtlpExportProtocol.Grpc;
            }));
```

Deployment env vars:
```yaml
env:
  - name: OTEL_SERVICE_NAME
    value: "your-dotnet-service"
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://localhost:4317"
```

### 3. Python Applications (FastAPI, Flask, Django)

Install packages:
```bash
pip install opentelemetry-distro opentelemetry-exporter-otlp
opentelemetry-bootstrap -a install
```

**Option A: Auto-instrumentation**
```bash
opentelemetry-instrument \
    --traces_exporter otlp \
    --metrics_exporter none \
    --service_name your-python-service \
    --exporter_otlp_endpoint http://localhost:4317 \
    python app.py
```

Dockerfile example:
```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
RUN pip install opentelemetry-distro opentelemetry-exporter-otlp && \
    opentelemetry-bootstrap -a install

ENV OTEL_SERVICE_NAME=your-python-service
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
ENV OTEL_TRACES_EXPORTER=otlp
ENV OTEL_METRICS_EXPORTER=none

COPY . .
CMD ["opentelemetry-instrument", "python", "app.py"]
```

### 4. Node.js Applications

Install packages:
```bash
npm install @opentelemetry/sdk-node \
            @opentelemetry/auto-instrumentations-node \
            @opentelemetry/exporter-trace-otlp-grpc
```

Create `tracing.js`:
```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');

const sdk = new NodeSDK({
  serviceName: process.env.OTEL_SERVICE_NAME || 'nodejs-service',
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4317',
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
```

Update `package.json`:
```json
{
  "scripts": {
    "start": "node -r ./tracing.js app.js"
  }
}
```

### 5. Go Applications

Install packages:
```bash
go get go.opentelemetry.io/otel
go get go.opentelemetry.io/otel/sdk
go get go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc
go get go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp
```

Example code:
```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/sdk/resource"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
)

func initTracer() (*sdktrace.TracerProvider, error) {
    exporter, err := otlptracegrpc.New(
        context.Background(),
        otlptracegrpc.WithEndpoint("localhost:4317"),
        otlptracegrpc.WithInsecure(),
    )
    if err != nil {
        return nil, err
    }

    tp := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(exporter),
        sdktrace.WithResource(resource.NewWithAttributes(
            semconv.SchemaURL,
            semconv.ServiceNameKey.String("your-go-service"),
        )),
    )
    otel.SetTracerProvider(tp)
    return tp, nil
}
```

## Testing

### 1. Send a test trace

Use the provided script:
```bash
./examples/otel-test-trace.sh
```

Or manually:
```bash
curl -X POST http://172.23.202.22:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [{
          "key": "service.name",
          "value": {"stringValue": "test-service"}
        }]
      },
      "scopeSpans": [{
        "spans": [{
          "traceId": "5b8aa5a2d2c872e8321cf37308d69df2",
          "spanId": "051581bf3cb55c13",
          "name": "test-operation",
          "kind": 1,
          "startTimeUnixNano": "1000000000000000000",
          "endTimeUnixNano": "1001000000000000000",
          "attributes": [{
            "key": "http.method",
            "value": {"stringValue": "GET"}
          }]
        }]
      }]
    }]
  }'
```

### 2. Verify traces in Tempo

```bash
# Check if trace exists
curl -s "http://172.23.202.22:3200/api/traces/5b8aa5a2d2c872e8321cf37308d69df2"

# Search for traces
curl -s "http://172.23.202.22:3200/api/search?tags=service.name=test-service&limit=10"
```

### 3. View in Grafana

1. **Explore Traces App:** http://172.23.202.22:3000/a/grafana-exploretraces-app/explore
2. **Service Map Dashboard:** http://172.23.202.22:3000/d/service-map/
3. **Trace Explorer (classic):** http://172.23.202.22:3000/explore → Select Tempo datasource

## Verification Checklist

After instrumenting your application:

- [ ] Application starts without errors
- [ ] OTel collector is running on the node: `systemctl status otel-collector`
- [ ] Traces appear in Tempo: `curl "http://172.23.202.22:3200/api/search?limit=10"`
- [ ] Service graph metrics in Prometheus: `curl "http://172.23.202.22:9090/api/v1/query?query=traces_service_graph_request_total"`
- [ ] Service map shows in Grafana dashboard
- [ ] Traces are searchable in Explore Traces app

## Troubleshooting

### No traces showing in Tempo

1. **Check OTel Collector logs:**
   ```bash
   ssh -i ~/.ssh/fci root@<node-ip> 'journalctl -u otel-collector -n 100'
   ```

2. **Verify application is sending traces:**
   ```bash
   # Check OTel collector metrics
   curl http://<node-ip>:4327/metrics | grep otelcol_receiver_accepted_spans
   ```

3. **Check Tempo logs:**
   ```bash
   ssh -i ~/.ssh/fci root@172.23.202.22 'journalctl -u tempo -n 100'
   ```

4. **Verify network connectivity:**
   ```bash
   # From application pod to OTel collector
   kubectl exec -it <pod-name> -- nc -zv localhost 4317
   ```

### Service graph not showing

1. **Verify Tempo is generating metrics:**
   ```bash
   curl http://172.23.202.22:3200/metrics | grep tempo_metrics_generator
   ```

2. **Check Prometheus is receiving metrics:**
   ```bash
   curl "http://172.23.202.22:9090/api/v1/query?query=traces_service_graph_request_total"
   ```

3. **Wait 1-2 minutes** - service graph metrics are generated with a delay

### High cardinality / performance issues

Adjust sampling rate in production:
```yaml
env:
  - name: OTEL_TRACES_SAMPLER
    value: "parentbased_traceidratio"
  - name: OTEL_TRACES_SAMPLER_ARG
    value: "0.1"  # Sample 10% of traces
```

Tempo tail sampling is already configured to keep:
- 100% of error traces
- 100% of slow traces (>1s latency)
- 25% of normal traces

## Resource Attributes

Standard attributes to include:
```yaml
OTEL_RESOURCE_ATTRIBUTES: >-
  service.name=my-service,
  service.version=1.0.0,
  deployment.environment=production,
  k8s.namespace.name=$(NAMESPACE),
  k8s.pod.name=$(POD_NAME),
  k8s.node.name=$(NODE_NAME),
  k8s.cluster.name=rke2
```

## Best Practices

1. **Use meaningful service names** - avoid generic names like "app" or "service"
2. **Add custom attributes** - business context, user IDs, transaction IDs
3. **Create custom spans** - for critical business operations
4. **Correlate with logs** - add `trace_id` to log output
5. **Monitor overhead** - OTel adds <5% CPU/memory overhead typically
6. **Sample in production** - don't trace 100% of requests in high-traffic services
7. **Use semantic conventions** - follow OpenTelemetry semantic conventions for attributes

## Example: Correlating Traces with Logs

### Logback (Java):
```xml
<pattern>%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} [trace_id=%X{trace_id} span_id=%X{span_id}] - %msg%n</pattern>
```

### Loki query to find logs for a trace:
```
{namespace="btxh-prod"} |= "trace_id=5b8aa5a2d2c872e8321cf37308d69df2"
```

### Grafana automatically links traces ↔ logs when:
- Logs have `traceId` field (structured metadata)
- Logs have `trace_id=xxx` in message
- Tempo datasource has `tracesToLogsV2` configured (already done)

## References

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Grafana Tempo Documentation](https://grafana.com/docs/tempo/latest/)
- [Java Agent Configuration](https://opentelemetry.io/docs/instrumentation/java/automatic/agent-config/)
- [Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/)
