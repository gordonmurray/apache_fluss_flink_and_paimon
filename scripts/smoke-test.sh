#!/usr/bin/env bash
# Smoke test for the Fluss + Flink + Paimon demo.
#
# Validates the Compose config, starts the stack, waits for the services to be
# healthy, runs a small Fluss SQL walkthrough (create catalog and table, insert
# rows, primary-key lookup) and checks the result. Exits non-zero on any failed
# health check or SQL validation.
#
# Usage:                 scripts/smoke-test.sh
# Keep the stack up:     KEEP_STACK=1 scripts/smoke-test.sh   (debug, then docker compose down -v)
set -euo pipefail

cd "$(dirname "$0")/.."

JOBMANAGER="${FLINK_JOBMANAGER_CONTAINER:-flink-jobmanager}"
REST="${FLINK_REST_URL:-http://localhost:8083}"
CORE_CONTAINERS="minio zk fluss-coordinator fluss-tablet flink-jobmanager flink-taskmanager"

fail() { echo "SMOKE TEST FAILED: $*" >&2; exit 1; }

echo "==> Validating Compose config"
docker compose config -q || fail "docker compose config is invalid"

echo "==> Building and starting the stack"
docker compose up -d --build

echo "==> Waiting for the JobManager to become healthy"
ok=
for _ in $(seq 1 60); do
  if [ "$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$JOBMANAGER" 2>/dev/null)" = "healthy" ]; then
    ok=1; break
  fi
  sleep 3
done
[ -n "$ok" ] || fail "JobManager did not become healthy in time"

echo "==> Waiting for a task manager to register"
ok=
for _ in $(seq 1 30); do
  n="$(curl -fsS "$REST/overview" 2>/dev/null \
    | python3 -c 'import sys,json; print(json.load(sys.stdin).get("taskmanagers",0))' 2>/dev/null || echo 0)"
  if [ "${n:-0}" -ge 1 ]; then ok=1; break; fi
  sleep 3
done
[ -n "$ok" ] || fail "no task manager registered in time"

echo "==> Checking core containers are running"
for c in $CORE_CONTAINERS; do
  [ "$(docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null)" = "true" ] || fail "container $c is not running"
done

echo "==> Running the Fluss SQL walkthrough"
SQL="$(cat <<'SQL'
SET 'execution.runtime-mode' = 'batch';
SET 'sql-client.execution.result-mode' = 'tableau';
SET 'table.dml-sync' = 'true';
CREATE CATALOG fluss_catalog WITH ('type' = 'fluss', 'bootstrap.servers' = 'coordinator-server:9123');
USE CATALOG fluss_catalog;
DROP TABLE IF EXISTS smoke_logins;
CREATE TABLE smoke_logins (id STRING, username STRING, ts TIMESTAMP(3), ip STRING, PRIMARY KEY (id) NOT ENFORCED);
INSERT INTO smoke_logins VALUES
  ('1', 'alice', TIMESTAMP '2025-09-03 09:00:00', '10.0.0.5'),
  ('2', 'bob',   TIMESTAMP '2025-09-03 09:05:00', '10.0.0.8');
SELECT * FROM smoke_logins WHERE id = '1';
SQL
)"

out=""
for attempt in 1 2 3; do
  echo "    SQL attempt ${attempt}"
  printf '%s\n' "$SQL" | docker exec -i "$JOBMANAGER" sh -c 'cat > /tmp/smoke.sql'
  out="$(docker exec "$JOBMANAGER" /opt/flink/bin/sql-client.sh -f /tmp/smoke.sql 2>&1 || true)"
  if printf '%s' "$out" | grep -q 'alice'; then break; fi
  sleep 10
done

if ! printf '%s' "$out" | grep -q 'alice'; then
  printf '%s\n' "$out" | tail -20 >&2
  fail "primary-key lookup did not return the expected row"
fi
echo "    primary-key lookup returned the expected row for id = 1"

if [ "${KEEP_STACK:-0}" = "1" ]; then
  echo "==> Smoke test passed. Stack left running (KEEP_STACK=1); stop it with: docker compose down -v"
else
  echo "==> Smoke test passed. Tearing down"
  docker compose down -v >/dev/null 2>&1 || true
fi
