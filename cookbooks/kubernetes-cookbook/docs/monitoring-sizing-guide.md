# Monitoring VM Sizing Guide

## 📊 Quick Reference

| Cluster Size | Nodes | CPU | RAM | Disk | Use Case |
|--------------|-------|-----|-----|------|----------|
| **Dev/Test** | 1-5 | 2 | 4 GB | 50 GB | Development, POC |
| **Small Production** | 5-10 | 4 | 8 GB | 100 GB | Small production clusters |
| **Medium Production** | 10-30 | 8 | 16 GB | 200 GB SSD | Standard production |
| **Large Production** | 30-50 | 16 | 32 GB | 500 GB SSD | Large-scale deployments |
| **Enterprise** | 50+ | 32 | 64 GB | 1 TB SSD | Enterprise, multi-cluster |

## 🔍 Detailed Resource Breakdown

### CPU Requirements

| Component | Base CPU | Per 1000 Series | Notes |
|-----------|----------|----------------|-------|
| **Prometheus** | 0.5-1 core | +0.5 core | Query-heavy workloads need more |
| **Grafana** | 0.5-1 core | - | Scales with dashboards & users |
| **Node Exporter** | 0.1 core | - | Minimal CPU usage |
| **AlertManager** | 0.2 core | - | Optional component |

**Your setup (3 nodes):**

- Estimated active series: ~3,000-5,000
- Recommended: **4 CPU cores**

### Memory Requirements

#### Prometheus Memory

```
Base Memory: 2 GB
Per 1000 active time series: +500 MB
Per 1M samples ingested/sec: +1 GB
Query buffer: +1-2 GB
```

**Formula:**

```
RAM = 2GB + (active_series / 1000 * 0.5GB) + 1GB query buffer
```

**Examples:**

- 3 nodes (5K series): 2 + 2.5 + 1 = **5.5 GB**
- 10 nodes (15K series): 2 + 7.5 + 2 = **11.5 GB**
- 30 nodes (50K series): 2 + 25 + 4 = **31 GB**

#### Grafana Memory

```
Base: 512 MB
Per 10 dashboards: +256 MB
Per 100 concurrent users: +512 MB
```

**Your setup:** ~1 GB for Grafana is sufficient

#### Total Memory Recommendation

| Cluster Size | Prometheus | Grafana | System | Total | Recommended |
|--------------|------------|---------|--------|-------|-------------|
| 3-5 nodes | 4 GB | 1 GB | 1 GB | 6 GB | **8 GB** |
| 5-10 nodes | 8 GB | 1 GB | 2 GB | 11 GB | **16 GB** |
| 10-30 nodes | 16 GB | 2 GB | 3 GB | 21 GB | **32 GB** |

### Disk Requirements

#### Storage Calculation

**Per node Prometheus metrics:**

- Scrape interval: 15s (default)
- Samples per scrape: ~500-1000 metrics
- Samples per day: `(24 * 3600 / 15) * 1000 = 5.76M samples`
- Storage per day per node: ~200-500 MB (compressed)

**Retention calculation:**

```
Disk = (nodes * 500MB * retention_days) * 1.5 safety margin
```

**Examples:**

| Nodes | 15 days | 30 days | 90 days |
|-------|---------|---------|---------|
| 3 | 34 GB | 68 GB | 203 GB |
| 10 | 112 GB | 225 GB | 675 GB |
| 30 | 337 GB | 675 GB | 2 TB |

**Your setup (3 nodes, 30 days):** ~70 GB Prometheus data

#### Total Disk Breakdown

```
/var/lib/prometheus/    : 50-70 GB (30-day retention, 3 nodes)
/var/lib/grafana/       : 2-5 GB (dashboards, plugins)
/var/log/               : 5-10 GB (logs)
/etc/                   : 1 GB (configs)
System                  : 10-15 GB
Total                   : ~70-100 GB
```

**Recommended: 100 GB for safety margin**

### Disk Type Recommendations

| Cluster Size | Disk Type | IOPS | Notes |
|--------------|-----------|------|-------|
| Dev/Test | HDD | 100+ | Cost-effective |
| Small Prod | SSD | 1000+ | Better performance |
| Medium+ Prod | NVMe SSD | 5000+ | High-performance queries |

## 🚀 Performance Optimization Tips

### 1. Memory Optimization

```yaml
# Prometheus memory tuning
prometheus --storage.tsdb.retention.size=45GB  # Limit disk usage
prometheus --query.max-samples=50000000        # Prevent OOM from large queries
```

### 2. CPU Optimization

- Use recording rules for frequently queried metrics
- Limit scrape frequency for high-cardinality metrics
- Use relabeling to drop unnecessary metrics

### 3. Disk Optimization

- Use SSD for better query performance
- Enable compression (default in Prometheus 2.x)
- Consider remote storage for long-term retention (Thanos, Cortex, Mimir)

## 📈 Scaling Guidelines

### When to Upgrade

**Upgrade CPU when:**

- Query latency > 5 seconds consistently
- CPU usage > 80% sustained
- Grafana dashboards loading slowly

**Upgrade RAM when:**

- Prometheus using > 80% memory
- OOM kills occurring
- Query failures due to memory limits

**Upgrade Disk when:**

- Disk usage > 80%
- Old data being deleted before retention period
- Write operations are slow

### Vertical vs Horizontal Scaling

**Vertical Scaling (Recommended for <50 nodes):**

- Increase VM resources
- Simpler setup
- Single Prometheus instance

**Horizontal Scaling (For 50+ nodes or multi-cluster):**

- Use Prometheus federation
- Deploy Thanos/Cortex/Mimir
- Multiple Prometheus instances with different scopes

## 🔧 Resource Monitoring

### Monitor Your Monitoring VM

Add these alerts to monitor the monitoring server:

```yaml
# CPU alert
- alert: MonitoringHighCPU
  expr: rate(node_cpu_seconds_total{mode="idle",instance="monitoring"}[5m]) < 0.2
  for: 10m

# Memory alert  
- alert: MonitoringHighMemory
  expr: node_memory_MemAvailable_bytes{instance="monitoring"} / node_memory_MemTotal_bytes{instance="monitoring"} < 0.2
  for: 5m

# Disk alert
- alert: MonitoringLowDisk
  expr: node_filesystem_avail_bytes{instance="monitoring",mountpoint="/var/lib/prometheus"} / node_filesystem_size_bytes < 0.2
  for: 5m
```

## 📊 Real-World Examples

### Example 1: Startup (Your Case)

- **Cluster:** 1 master, 2 workers (3 nodes)
- **Pods:** ~20-50 pods
- **Metrics:** ~5,000 active series
- **Retention:** 30 days
- **Recommended:** 4 CPU, 8 GB RAM, 100 GB disk
- **Cost:** ~$40-80/month (cloud)

### Example 2: Small Company

- **Cluster:** 3 masters, 5 workers (8 nodes)
- **Pods:** ~100-200 pods
- **Metrics:** ~12,000 active series
- **Retention:** 30 days
- **Recommended:** 4 CPU, 16 GB RAM, 200 GB SSD
- **Cost:** ~$100-150/month

### Example 3: Medium Company

- **Cluster:** Multi-cluster (20 nodes total)
- **Pods:** ~500+ pods
- **Metrics:** ~30,000 active series
- **Retention:** 90 days
- **Recommended:** 8 CPU, 32 GB RAM, 500 GB SSD + Thanos
- **Cost:** ~$300-500/month

## 🎯 Recommendation for Your Setup

Based on your inventory (1 master + 2 workers + 1 monitoring):

```
Optimal Configuration:
├── CPU: 4 cores
├── RAM: 8 GB
├── Disk: 100 GB
├── OS: Ubuntu 22.04 LTS
└── Network: 1 Gbps

This provides:
✓ Comfortable headroom for growth (2x capacity)
✓ 30-day metric retention
✓ Fast query performance
✓ Room for 10-15 Grafana dashboards
✓ Support for 5-10 concurrent users
✓ Can scale to 10 nodes before upgrade needed
```

## 💰 Cost Optimization

### Cloud Provider Estimates (Monthly)

| Provider | Instance Type | CPU | RAM | Disk | Cost/Month |
|----------|---------------|-----|-----|------|------------|
| **AWS** | t3.large | 2 | 8 GB | 100 GB GP3 | ~$85 |
| **AWS** | t3.xlarge | 4 | 16 GB | 100 GB GP3 | ~$150 |
| **Azure** | B2ms | 2 | 8 GB | 100 GB | ~$70 |
| **Azure** | D2s v3 | 2 | 8 GB | 100 GB | ~$95 |
| **GCP** | e2-standard-2 | 2 | 8 GB | 100 GB | ~$65 |
| **GCP** | e2-standard-4 | 4 | 16 GB | 100 GB | ~$130 |

**Note:** Prices vary by region and commitment term

### Save Money By

1. Using spot/preemptible instances (50-70% savings)
2. Reserved instances (30-60% savings)
3. Right-sizing based on actual usage
4. Using cheaper regions
5. Implementing retention policies (15 days vs 90 days)

## 📚 Additional Resources

- [Prometheus Sizing Calculator](https://www.robustperception.io/how-much-ram-does-prometheus-2-x-need-for-cardinality-and-ingestion/)
- [Grafana Performance Testing](https://grafana.com/docs/grafana/latest/administration/provisioning/)
- [Thanos Architecture](https://thanos.io/tip/thanos/design.md/) - For scaling beyond single Prometheus

---

**Created:** February 2026  
**Last Updated:** February 2026  
**Author:** XDEV Asia Labs
