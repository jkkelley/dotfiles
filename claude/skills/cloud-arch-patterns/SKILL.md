---
name: cloud-arch-patterns
description: Cloud architecture patterns, decision frameworks, and cost/reliability reference across AWS, GCP, and Azure. Preloaded into the solutions-architect agent.
---

# Cloud Architecture Patterns

## Architecture Decision Framework

Before proposing any solution, establish:
1. **Scale**: current and 2-year projected (req/s, data volume, users)
2. **SLA**: uptime requirement (99.9% = 8.7h/yr downtime, 99.99% = 52m/yr)
3. **RPO/RTO**: how much data loss and how long to recover are acceptable
4. **Compliance**: HIPAA, PCI-DSS, SOC2, FedRAMP, GDPR, data residency
5. **Team**: size, cloud expertise, operational maturity
6. **Budget**: capex vs opex constraints

## Availability Tiers

| SLA | Downtime/yr | Pattern |
|-----|-------------|---------|
| 99.5% | 43h | Single region, multi-AZ |
| 99.9% | 8.7h | Multi-AZ, automated failover |
| 99.95% | 4.4h | Multi-region active-passive |
| 99.99% | 52m | Multi-region active-active |
| 99.999% | 5m | Cell-based, global distribution |

## Core Patterns by Use Case

### Web Application (3-tier)
```
CDN (CloudFront/Cloud CDN/Front Door)
  ↓
WAF + Load Balancer (ALB/GLB/Application Gateway)
  ↓
Compute (ECS Fargate / Cloud Run / Container Apps) — 3 AZs min
  ↓
Cache (ElastiCache Redis / Memorystore / Azure Cache)
  ↓
Database (Aurora Multi-AZ / Cloud SQL HA / Azure SQL BC)
  ↓
Object Storage (S3 / GCS / Blob Storage) — static assets
```

### Event-Driven / Async Processing
```
Producers → Message Queue (SQS/Pub-Sub/Service Bus)
              ↓
          Consumer (Lambda/Cloud Functions/Azure Functions)
              ↓
          Dead Letter Queue → Alert
```

### Data Platform
```
Ingestion: Kinesis/Pub-Sub/Event Hubs
  ↓
Stream Processing: Flink/Dataflow/Stream Analytics
  ↓
Storage: S3/GCS/ADLS (data lake, Parquet/Delta)
  ↓
Warehouse: Redshift/BigQuery/Synapse
  ↓
BI: QuickSight/Looker/Power BI
```

### Microservices
```
API Gateway → Service Mesh (Istio/Cloud Service Mesh/Dapr)
  ↓
Services (EKS/GKE/AKS) — each owns its DB
  ↓
Async: Event bus for cross-service communication
  ↓
Observability: OTEL → traces + metrics + logs
```

## DR Strategies

| Strategy | RPO | RTO | Cost | When |
|----------|-----|-----|------|------|
| Backup & Restore | Hours | Hours | $ | Dev, low-criticality |
| Pilot Light | Minutes | ~1h | $$ | Most production |
| Warm Standby | Seconds | Minutes | $$$ | High-value workloads |
| Active-Active | Near-zero | Seconds | $$$$ | Mission-critical |

**Route 53 / Cloud DNS failover setup:**
- Health check interval: 30s
- Failure threshold: 3 consecutive failures
- TTL on DNS records: 60s (low for fast failover)
- Test failover quarterly — untested DR is no DR

## Cost Optimization Quick Wins

| Action | Typical Savings |
|--------|----------------|
| Reserved/Committed use (1yr) | 30-40% |
| Spot/Preemptible for stateless | 60-90% |
| S3/GCS Intelligent Tiering | 20-40% on storage |
| RDS Reserved | 40% |
| Right-size with Compute Optimizer | 10-30% |
| Delete unattached EBS volumes | Variable |
| NAT Gateway → VPC endpoints for AWS services | Variable |
| Lifecycle policies on logs/backups | Significant |

## IAM Least Privilege Patterns

```
Never:  Action: "*", Resource: "*"
Never:  Use root credentials for anything
Always: SCPs at Org level to set guardrails
Always: Permission Boundaries for delegated admin
Always: Separate roles per service, per environment
Always: Rotate credentials; prefer temporary (IRSA, Workload Identity)
```

## Networking Quick Reference

### AWS VPC Subnet Design (3-tier, 3-AZ)
```
VPC: 10.x.0.0/16

Public  (ALB, NAT GW): /24 per AZ → 10.x.0-2.0/24
Private (App, EKS):    /22 per AZ → 10.x.10-22.0/22  (1022 hosts each)
Isolated (DB, Cache):  /24 per AZ → 10.x.20-22.0/24
```

### Service Endpoint Strategy
```
Internal services   → Private endpoints / VPC endpoints (no internet)
External services   → NAT GW (egress only) or PrivateLink
Admin access        → SSM Session Manager (no bastion, no SSH port)
Cross-account       → AWS RAM or PrivateLink, not VPC peering for many accounts
Multi-account       → Transit Gateway (hub-spoke) or AWS Network Firewall
```

## Security Posture Checklist

```
[ ] No public S3 buckets (use bucket policy + Block Public Access)
[ ] CloudTrail enabled in all regions, logs to separate account
[ ] GuardDuty + Security Hub enabled
[ ] No long-lived IAM user access keys in production
[ ] VPC Flow Logs enabled
[ ] KMS CMKs for sensitive data at rest
[ ] TLS 1.2+ enforced, TLS 1.0/1.1 disabled
[ ] WAF on all public-facing endpoints
[ ] Config rules for continuous compliance
[ ] Patch management: SSM Patch Manager or equivalent
```

## Anti-Patterns to Always Flag

- Single-AZ for anything in production
- Public S3 bucket (immediate block)
- Hardcoded credentials in Lambda env vars or EC2 user data
- No backup / untested backups
- Lift-and-shift without rightsizing (cloud ≠ cheap by default)
- Over-engineering: microservices for a 2-person startup
- Stateful app on spot instances without checkpoint/resumption
- No egress controls (data exfiltration risk)
