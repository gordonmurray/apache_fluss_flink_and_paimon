# apache_fluss_flink_and_paimon
A small project to use and learn Apache Fluss, with Apache Flink and Apache Paimon




docker exec -it flink-jobmanager /opt/flink/bin/sql-client.sh


### Create a table

```
CREATE CATALOG fluss_catalog WITH (
  'type' = 'fluss',
  'bootstrap.servers' = 'coordinator-server:9123'
);

```
USE CATALOG fluss_catalog;

```


CREATE TABLE logins (
  id STRING,
  username STRING,
  ts TIMESTAMP(3),
  ip STRING,
  PRIMARY KEY (id) NOT ENFORCED
);


INSERT INTO logins VALUES
  ('1','alice',TIMESTAMP '2025-09-03 09:00:00','10.0.0.5'),
  ('2','bob',  TIMESTAMP '2025-09-03 09:05:00','10.0.0.8');


SET 'sql-client.execution.result-mode' = 'tableau';

SET 'execution.runtime-mode' = 'batch';


SELECT * FROM logins WHERE id = '1';


