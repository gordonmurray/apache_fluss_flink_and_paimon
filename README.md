# apache_fluss_flink_and_paimon
A small project to use and learn Apache Fluss, with Apache Flink and Apache Paimon

This project integrates Apache Fluss (stream-batch unified storage) with Apache Paimon (data lake storage) using Apache Flink. This allows you to:
- Use Fluss for real-time stream processing with primary key queries
- Use Paimon for analytics queries on non-primary key fields
- Transfer data between the two systems seamlessly

## Services
- **Fluss**: Stream-batch unified storage
- **Paimon**: Data lake storage with S3 (MinIO)
- **Flink**: Stream/batch processing engine
- **MinIO**: S3-compatible object storage
- **Zookeeper**: Coordination service

## Getting Started

Start all services:
```bash
docker compose up -d
```

Access Flink SQL client:
```bash
docker exec -it flink-jobmanager /opt/flink/bin/sql-client.sh
```

## Complete Step-by-Step Workflow

### Step 1: Create Fluss Catalog and Table

```sql
-- Create Fluss catalog
CREATE CATALOG fluss_catalog WITH (
  'type' = 'fluss',
  'bootstrap.servers' = 'coordinator-server:9123'
);

-- Switch to Fluss catalog
USE CATALOG fluss_catalog;

-- Create table in Fluss (optimized for primary key queries)
CREATE TABLE logins (
  id STRING,
  username STRING,
  ts TIMESTAMP(3),
  ip STRING,
  PRIMARY KEY (id) NOT ENFORCED
);

-- Insert sample data into Fluss
INSERT INTO logins VALUES
  ('1','alice',TIMESTAMP '2025-09-03 09:00:00','10.0.0.5'),
  ('2','bob',  TIMESTAMP '2025-09-03 09:05:00','10.0.0.8'),
  ('3','alice',TIMESTAMP '2025-09-04 09:05:00','10.0.0.5');

-- Query by primary key (efficient in Fluss)
SET 'sql-client.execution.result-mode' = 'tableau';
SET 'execution.runtime-mode' = 'batch';
SELECT * FROM logins WHERE id = '1';
```

### Step 2: Create Paimon Catalog and Table

```sql
-- Create Paimon catalog
CREATE CATALOG paimon_catalog WITH (
    'type' = 'paimon',
    'warehouse' = 's3://warehouse/',
    's3.endpoint' = 'http://minio:9000',
    's3.access-key' = 'admin',
    's3.secret-key' = 'password123',
    's3.path-style-access' = 'true'
);

-- Switch to Paimon catalog
USE CATALOG paimon_catalog;

-- Create table in Paimon (optimized for analytics queries)
CREATE TABLE user_analytics (
  id STRING,
  username STRING,
  ts TIMESTAMP(3),
  ip STRING,
  PRIMARY KEY (id) NOT ENFORCED
);
```

### Step 3: Transfer Data from Fluss to Paimon

Due to Fluss limitations (only supports primary key queries in batch mode), use this manual approach:

```sql
-- Switch to Paimon catalog
USE CATALOG paimon_catalog;

-- Manually insert the data from Fluss into Paimon
-- (In a real scenario, you'd automate this via streaming jobs)
INSERT INTO user_analytics VALUES
  ('1','alice',TIMESTAMP '2025-09-03 09:00:00','10.0.0.5'),
  ('2','bob',  TIMESTAMP '2025-09-03 09:05:00','10.0.0.8'),
  ('3','alice',TIMESTAMP '2025-09-04 09:05:00','10.0.0.5');

-- Verify data was transferred
SELECT * FROM user_analytics;

-- Now run analytics queries (efficient in Paimon)
SELECT username, COUNT(*) as login_count, MAX(ts) as last_login
FROM user_analytics 
GROUP BY username;

-- Query by IP address (not efficient in Fluss, but works great in Paimon)
SELECT * FROM user_analytics 
WHERE ip = '10.0.0.5';

-- Query by date range
SELECT * FROM user_analytics 
WHERE ts >= TIMESTAMP '2025-09-04 00:00:00';
```

### Step 4: Querying Each System

**Fluss** (Primary key queries only):
```sql
USE CATALOG fluss_catalog;
-- Only primary key queries work efficiently
SELECT * FROM logins WHERE id = '1';
```

**Paimon** (Full analytics capabilities):
```sql
USE CATALOG paimon_catalog;
-- All query types work
SELECT * FROM user_analytics WHERE username = 'alice';
SELECT * FROM user_analytics WHERE ip = '10.0.0.5';
SELECT username, COUNT(*) FROM user_analytics GROUP BY username;
```

### Step 5: Real-time Streaming (Advanced)

For production use, you'd set up streaming jobs to automatically sync data:

```sql
-- Set streaming mode for real-time data transfer
SET 'execution.runtime-mode' = 'streaming';

-- In practice, you'd need to:
-- 1. Enable datalake mode on Fluss tables
-- 2. Use Flink streaming jobs for automatic data transfer
-- 3. Set up proper schema evolution and conflict resolution
```

## Architecture Benefits

- **Fluss**: Fast primary key lookups, real-time updates, stream processing
- **Paimon**: Complex analytics, historical data, efficient non-primary key queries
- **Combined**: Real-time operational queries + comprehensive analytics

## Troubleshooting

### Common Issues:

1. **StatusLogger Reconfiguration Error**: This is a harmless logging configuration warning that can be ignored.

2. **Cross-catalog queries fail**: 
   - Current Fluss/Flink setup has limitations with cross-catalog references
   - Use manual data transfer approach shown in Step 3
   - Fluss only supports primary key queries in batch mode

3. **"Object 'logins' not found within 'fluss_catalog'"**: 
   - Cross-catalog references don't work in this setup
   - Use separate INSERT statements for each catalog

3. **S3 Connection Issues**: 
   - Verify MinIO is healthy: `docker compose ps`
   - Check MinIO UI at http://localhost:9001
   - Ensure buckets are created: `minio/warehouse` and `minio/checkpoints`

### Useful Commands:

```sql
-- List all catalogs
SHOW CATALOGS;

-- List tables in current catalog
SHOW TABLES;

-- Check Fluss catalog tables
USE CATALOG fluss_catalog;
SHOW TABLES;

-- Check Paimon catalog tables  
USE CATALOG paimon_catalog;
SHOW TABLES;
```


