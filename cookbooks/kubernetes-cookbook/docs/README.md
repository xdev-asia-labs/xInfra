# Documentation Index

This directory contains documentation for the Kubernetes monitoring and observability stack.

## Available Documentation

### Observability & Instrumentation

- **[Tracing Instrumentation Guide](./tracing-instrumentation.md)** - Complete guide to instrument applications with OpenTelemetry for distributed tracing

## Quick Links

### Monitoring Stack

- **Prometheus**: http://172.23.202.22:9090
- **Grafana**: http://172.23.202.22:3000 (admin/admin)
- **Loki**: http://172.23.202.22:3100
- **Tempo**: http://172.23.202.22:3200

### Grafana Apps

- **Explore Traces**: http://172.23.202.22:3000/a/grafana-exploretraces-app/explore
- **Explore Loki**: http://172.23.202.22:3000/a/grafana-lokiexplore-app/explore
- **Service Map**: http://172.23.202.22:3000/d/service-map/

## Getting Started

### 1. View Metrics

Access Grafana and explore pre-configured dashboards:
- Kubernetes cluster monitoring (Dashboard ID 315)
- Node Exporter Full (Dashboard ID 1860)

### 2. Query Logs

Use Loki datasource in Grafana:
```logql
{namespace="btxh-prod"} |= "error"
{job="systemd-journal"} | json | level="ERROR"
```

### 3. Instrument Applications for Tracing

Follow the [Tracing Instrumentation Guide](./tracing-instrumentation.md) to add distributed tracing to your applications.

Quick test:
```bash
cd examples/
./otel-test-trace.sh
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                          │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    │
│  │ Application  │───▶│     OTel     │───▶│    Tempo     │    │
│  │    Pods      │    │  Collector   │    │  (traces)    │    │
│  └──────────────┘    │  (DaemonSet) │    └──────────────┘    │
│         │             └──────────────┘            │            │
│         │                     │                   │            │
│         │                     │                   │            │
│  ┌──────▼──────┐      ┌──────▼──────┐    ┌──────▼──────┐    │
│  │  Promtail   │─────▶│     Loki    │◀───│  Grafana    │    │
│  │ (DaemonSet) │      │   (logs)    │    │ (dashboards)│    │
│  └─────────────┘      └─────────────┘    └──────▲──────┘    │
│                                                   │            │
│                       ┌───────────────────────────┘            │
│                       │                                        │
│              ┌────────▼────────┐                              │
│              │   Prometheus    │                              │
│              │   (metrics)     │                              │
│              └─────────────────┘                              │
│                                                                 │
│  Monitoring VM: 172.23.202.22                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Stack Versions

| Component | Version | Notes |
|-----------|---------|-------|
| Grafana | 12.3.2 | Built-in Explore apps |
| Prometheus | 2.48.1 | With remote write |
| Loki | 3.6.5 | TSDB + pattern ingester |
| Tempo | 2.8.3 | TraceQL, metrics generator |
| Promtail | 3.6.5 | System + K8s logs |
| OTel Collector | 0.91.0 | Contrib distro |
| Node Exporter | 1.7.0 | System metrics |

## Common Tasks

### Add a New Service to Monitoring

1. Ensure service exposes `/metrics` endpoint (Prometheus format)
2. Add scrape config to Prometheus (via Ansible)
3. Deploy with service discovery labels

### View Pod Logs

```bash
# Via kubectl
kubectl logs -n namespace pod-name -f

# Via Loki (in Grafana)
{namespace="namespace", pod="pod-name"}
```

### Search for Traces

```bash
# Via Tempo API
curl "http://172.23.202.22:3200/api/search?tags=service.name=my-service"

# Via Grafana Explore
# Select Tempo datasource, use TraceQL:
{service.name="my-service" && duration > 1s}
```

### Correlate Logs & Traces

When traces have `traceId` in logs:
```logql
{namespace="btxh-prod"} | json | traceId="abc123def456"
```

Grafana automatically shows "Related logs" in trace view.

## Troubleshooting

### Service Not Showing Metrics

1. Check Prometheus targets: http://172.23.202.22:9090/targets
2. Verify service labels match scrape config
3. Check network policies allow Prometheus access

### No Logs in Loki

1. Check Promtail status: `systemctl status promtail`
2. Verify Loki URL in Promtail config
3. Check Promtail logs: `journalctl -u promtail -f`

### Missing Traces

See [Tracing Instrumentation Guide - Troubleshooting](./tracing-instrumentation.md#troubleshooting)

## Contributing

When adding new documentation:
1. Create Markdown files in this directory
2. Update this index
3. Follow existing formatting conventions
4. Include practical examples

## External Resources

- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Tempo Documentation](https://grafana.com/docs/tempo/latest/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
