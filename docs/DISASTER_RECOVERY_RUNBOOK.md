# Atlas Disaster Recovery Runbook (RPO < 1m, RTO < 15m)

## 1. Objectives & Recovery Targets
- **RPO (Recovery Point Objective)**: < 60 seconds (Continuous Write-Ahead Log streaming).
- **RTO (Recovery Time Objective)**: < 15 minutes (Full failover to secondary cloud region).

---

## 2. Automated Backup Strategy
1. **Continuous WAL Archiving**: Every PostgreSQL transaction is streamed to encrypted immutable cloud object storage (AWS S3 Glacier / Cloudflare R2).
2. **Daily Physical Snapshots**: Full base backups taken daily at 03:00 UTC. Retained for 30 days.
3. **Weekly Cold Archives**: Stored across multi-region geographic vaults with 1-year retention.

---

## 3. Incident Escalation & Failover Drill

### Step 1: Severity Assessment
- Detect multi-AZ database failure or cloud provider outage via `InfrastructureMonitoringService`.
- Alert triggered: `alert_database_unreachable` (Severity: CRITICAL).

### Step 2: DNS & Traffic Rerouting
- Route 53 / Cloudflare Traffic Steering reroutes API Gateway traffic from Primary Region (`us-east-1`) to Standby Region (`us-west-2`).

### Step 3: Read Replica Promotion
```bash
# Promote Standby Read Replica to Primary Read/Write
supabase db promote --region us-west-2
```

### Step 4: Verification & Smoke Test
- Run `flutter test test/unit/scalability_test.dart`.
- Verify write operations on `workouts` and `fitness_memories`.
