# Demonstrating Transactions

Follow the [setup instructions](https://github.com/klauck/demo_dbs_internals?tab=readme-ov-file#setup), then connect to PostgreSQL using `psql` as described in the guide.

## Motivation: Sources of Inconsistencies

### Multiple Concurrent DBS Users

Two concurrent users could read and write the same data at the same time, leading to inconsistencies.

```sql
SELECT c_acctbal
FROM customer
WHERE c_custkey = 17;
```

```sql
UPDATE customer
SET c_acctbal = c_acctbal - 100
WHERE c_custkey = 17;
```


### Multiple SQL Statements

If **autocommit** is enabled (which is the default), the following statements execute as **two separate transactions**:


```sql
UPDATE supplier
SET s_acctbal = s_acctbal + 100
WHERE s_suppkey = 42;
```

```sql
UPDATE customer
SET c_acctbal = c_acctbal - 100
WHERE c_custkey = 17;
```

Other concurrent transactions could observe an **inconsistent state**:

```sql
SELECT s_suppkey, s_acctbal
FROM supplier
WHERE s_suppkey = 42;
```

```sql
SELECT c_custkey, c_acctbal
FROM customer
WHERE c_custkey = 17;
```

To ensure consistency, you should group both updates within a single transaction:

```sql
BEGIN TRANSACTION;    -- or use `START TRANSACTION`

-- Execute your SQL statements here

COMMIT;
```

Note: This does not ensure *full* consistency. Possible **anomalies** depend on the set **isolation level**.

If needed, an active transaction can be **aborted**, which **rolls back all uncommitted changes**:


```sql
BEGIN TRANSACTION;

-- Execute your SQL statements here

ABORT; -- Rolls back all transaction changes
```

Database systems might also abort automatically due to serialization conflicts or deadlocks.




### Multiple Writes Inside a Single Statement

**Implicit transaction** for single statements:

```sql
UPDATE orders
SET o_orderpriority = '1-URGENT'
WHERE o_custkey = 17;
```

## Isolation Levels

### Show Current Isolation Level

```sql
SHOW TRANSACTION ISOLATION LEVEL;
```

### Set Isolation Level for a Transaction

```sql
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- Execute your SQL statements here

COMMIT;
```
