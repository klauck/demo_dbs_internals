# Hands-On PostgreSQL Demonstrations for Teaching and Learning Database System Internals

We present a collection of demonstrations for teaching and learning database system internals using PostgreSQL.
The demonstrations cover key aspects of the database representation on disk and query processing, visualized in the following graphic.

<img src="https://github.com/klauck/demo_dbs_internal/blob/main/figures/demonstrated_database_system_internals.png" width="400" />

## Demonstrations per Lecture Topic
The demonstrations can be directly integrated into lectures about database system internals, for example, by switching between slide presentations giving background and hands-on demonstrations using PostgreSQL’s command line tool `psql`. We list common lecture topics and suitable demonstrations in the following table.

| Lecture Topic                | Suitable Demonstrations                                                                               |
|:----------------------------:|-------------------------------------------------------------------------------------------------------|
| Database Representation      | File organization <br> (Slotted) Page structure <br> Tuple representation                             |
| Caching                      | Buffer inspection                                                                                     | 
| Indexing                     | Index representation on disk <br> Index utilization (sequential scan vs. index scan vs. bitmap scan)  | 
| Query Execution              | Physical query plan <br> Buffer usage                                                                 | 
| Query Optimization           | Statistics <br> Cardinality estimation <br> Cost model <br> Query plan inspection                     | 
| Concurrency Control          | Inspect running transactions <br> Inspect MVCC columns <br> Row locking                               | 
| Recovery                     | Inspect running transactions <br> Inspect the write-ahead log                                         | 


## Demonstrations

### Setup

You can run the demonstrations on an existing PostgreSQL installation.
However, some experiments may require **superuser** privileges.
Also, the **data-loading scripts must be modified** if you are not using Docker.

### Docker Setup

Alternatively, you can run the demonstrations using Docker.

**1. Get the Scripts and Data**

```
git clone https://github.com/klauck/demo_dbs_internals.git
cd demo_dbs_internals
```


**2. Create and Start the Container**
   
   Ensure you **execute the following command from the root folder of the Git repository** to provide access to scripts and data:
   
```
docker run --name demo_postgres \
-v .:/root \
-e POSTGRES_USER=postgres \
-e POSTGRES_HOST_AUTH_METHOD=trust \
-e POSTGRES_DB=demo_db_internals \
-p 5432:5432 \
-d postgres:17
```
  
**3. Load TPC-H Data**

We provide a script to load TPC-H data with a scale factor of 0.01:

```
sh scripts/load_tpch.sh
```

**4. Connect to PostgreSQL**
   To connect using `psql`:

```
docker exec -it demo_postgres psql -U postgres -d demo_db_internals
```

**5. Manage the Container**
   - Stop the container:

```
docker stop demo_postgres
```

- Start the container again:

```
docker start demo_postgres
```

**6. Open the Container Shell**

Open a shell in the container, e.g., for inspecting the created files by PostgreSQL

```
docker exec -it demo_postgres bash
```



### Database Representation on Disk

#### Settings

The view [`pg_settings`](https://www.postgresql.org/docs/current/view-pg-settings.html) provides access to PostgreSQL’s configuration settings, including parameter names (`name`), current values (`setting`), and units (`unit`). We can use the `SHOW` and `SET` commands to display and change individual (e.g., `SHOW name`) or all (e.g., `SHOW ALL`) configuration parameters.

#### File organization

Show the directory in which PostgreSQL stores its configuration and data (e.g., tables, indexes) files.

```sql
SELECT setting FROM pg_settings WHERE name = 'data_directory';
```

```
          setting           
----------------------------
 /opt/homebrew/var/postgres
```

Within this directory, there is a subdirectory for every database, which groups a set of tables.
Each database has an assigned OID (Object Identifier), which can be queried:

```sql
SELECT oid FROM pg_database WHERE datname = 'demo_db_internals';
```
```
   oid    
----------
 17843524
```
Inside the database subdirectory, data files (e.g., for specific tables) are stored.
The following query returns the file name for the `region` table:

```sql
SELECT relfilenode FROM pg_class WHERE relname = 'region';
```
```
 relfilenode 
-------------
       16821
```

The `region` table is, thus, stored in the file `/opt/homebrew/var/postgres/base/17843524/16821`.

Or we can directly query the file path for a relation based on the PostgreSQL directory:

```sql
SELECT pg_relation_filepath('region');
```
```
 pg_relation_filepath 
----------------------
 base/16817/16821
```

#### Page structure

PostgreSQL organizes individual data files
into fixed-size slotted pages (default 8 KB). Each page consists of:
- A 24-byte header, storing metadata, e.g., available free space.
- An array of 4-byte tuple pointers, referencing stored tuples.
- The record data, containing actual table rows.

We can examine the internal structure of a page using the [`pageinspect`](https://www.postgresql.org/docs/current/pageinspect.html) extension. 

##### Heap file

Inspect the page header of the `region` table's first block

```sql
CREATE EXTENSION pageinspect;
SELECT * FROM page_header(get_raw_page('region', 0));
```
```
    lsn    | checksum | flags | lower | upper | special | pagesize | version | prune_xid 
-----------+----------+-------+-------+-------+---------+----------+---------+-----------
 0/1B67540 |        0 |     0 |    44 |  7568 |    8192 |     8192 |       4 |         0
```

Based on the header data, we can determine (1) how much space is left on the page (upper-lower) and (2) how many tuples ((lower-header_size)/pointer_size = (44 − 24)/4 = 5)
are stored on the page.

#### Tuple representation

We can also inspect individual tuples stored per page, including the line pointers (`lp`), byte offsets (`lp_off`), and MVCC information (`t_xmin`, `t_xmax`, `t_ctid`):

```sql
SELECT *
FROM heap_page_items(get_raw_page('region', 0));
```

```
 lp | lp_off | lp_flags | lp_len | t_xmin | t_xmax | t_field3 | t_ctid | t_infomask2 | t_infomask | t_hoff | t_bits | t_oid | t_data                                                                                                                                                 
----+--------+----------+--------+--------+--------+----------+--------+-------------+------------+--------+--------+-------+----------
  1 |   8016 |        1 |    170 |    938 |      0 |        0 | (0,1)  |           3 |       2306 |     24 |        |       | \x000...
  2 |   7928 |        1 |     86 |    938 |      0 |        0 | (0,2)  |           3 |       2306 |     24 |        |       | \x010...
  3 |   7840 |        1 |     86 |    938 |      0 |        0 | (0,3)  |           3 |       2306 |     24 |        |       | \x020...
  4 |   7736 |        1 |    100 |    938 |      0 |        0 | (0,4)  |           3 |       2306 |     24 |        |       | \x030...
  5 |   7568 |        1 |    163 |    938 |      0 |        0 | (0,5)  |           3 |       2306 |     24 |        |       | \x040...
```

##### Index file


### Query Processing

#### Statistics

Relation-level statistics, such as the estimated number of tuples (`reltuples`) and the relation size in pages (`relpages`), are stored in the catalog table `pg_class`.

```sql
SELECT reltuples, relpages FROM pg_class WHERE relname = 'nation';
```

```
 reltuples | relpages 
-----------+----------
        25 |        1
```

Attribute-level statistics can be queried using the view [`pg_stats`](https://www.postgresql.org/docs/current/view-pg-stats.html):

```sql
SELECT null_frac, n_distinct, most_common_vals, most_common_freqs, correlation
FROM pg_stats
WHERE tablename = 'nation' and attname = 'n_regionkey';
```
```
 null_frac | n_distinct | most_common_vals |   most_common_freqs   | correlation 
-----------+------------+------------------+-----------------------+-------------
         0 |       -0.2 | {0,1,2,3,4}      | {0.2,0.2,0.2,0.2,0.2} |   0.3476923
```
The queried statistics contain:
- `null_frac` - the fraction of `NULL` values
- `n_distinct` - the number of distinct values; a negative value means that PostgreSQL assumes the number of distinct values increases with the table cardinality, estimating it as -`reltuples`/`ndistinct`
- `most_common_vals` and `most_common_freqs` - the most common values and their frequencies
- `correlation` - indicating the sortedness of the table (`correlation=1` means sorted; `correlation≈0` means unsorted)

**Further examples:**

The statistics for the `n_nationkey` attribute indicate that the values are unique (`n_distinct`) and sorted (`correlation`)
```sql
SELECT n_distinct, correlation
FROM pg_stats
WHERE tablename = 'nation' and attname = 'n_nationkey';
```
```
 n_distinct | correlation 
------------+-------------
         -1 |           1
```

In case relations contain many distinct values, histograms indicate the value distribution. Note, the values are unsorted (`correlation`≈0)
```sql
SELECT n_distinct, histogram_bounds, correlation
FROM pg_stats
WHERE tablename = 'orders' and attname = 'o_totalprice';
```

```
 n_distinct  |                         histogram_bounds                         |  correlation  
-------------+------------------------------------------------------------------+---------------
 -0.94982266 | {877.30, 5178.77, 10127.58, 14137.17, 18301.12, ..., 522720.61}  | -0.0013608444
```

#### Query plan inspection

##### Estimated execution costs, cardinalities, and query plan

The well-known [`EXPLAIN`](https://www.postgresql.org/docs/current/sql-explain.html) command offers outputs in different format (i.e., `TEXT`, `JSON`, `XML`, `YAML`) and exposes total execution costs (`cost`), estimated cardinalities (`rows`), and information per operator.
```sql
EXPLAIN SELECT * FROM nation WHERE n_regionkey=4;
```

```
                       QUERY PLAN                       
--------------------------------------------------------
 Seq Scan on nation  (cost=0.00..1.31 rows=5 width=109)
   Filter: (n_regionkey = 4)
```
PostgreSQL does not expose a detailed cost breakdown to the user (only per operator).
For simple queries, the estimated costs can be explained with the available documentation.
For example, the costs (1.31 ≈ 1.3125 = 1 * 1.0 + 25 * 0.01 + 25 * 0.0025) for the query are composed of costs for sequentially scanning all table's pages (1 * `seq_page_cost`), accessing all table's tuples (25 * `cpu_tuple_cost`), and operations on all table's tuples operator costs (25 * `cpu_operator_cost`)

Recap, we can query current [settings](#settings):

```sql
SHOW seq_page_cost;
```
```
 seq_page_cost 
---------------
 1
```
```sql
SHOW cpu_tuple_cost;
```
```
 cpu_tuple_cost 
----------------
 0.01
```
```sql
SHOW cpu_operator_cost;
```
```
 cpu_operator_cost 
-------------------
 0.0025
```

##### Index utilization (sequential scan vs. index scan vs. bitmap scan)

Using the `EXPLAIN` command, we can show whether and how an index is used:

Create an index:
```sql
CREATE INDEX ON orders(o_totalprice);
```

Show usage for low estimated result cardinality (1 expected row):
```sql
EXPLAIN SELECT *
FROM orders
WHERE o_totalprice = 10127.58;
```
```
                                       QUERY PLAN                                       
----------------------------------------------------------------------------------------
 Index Scan using orders_o_totalprice_idx on orders  (cost=0.43..2.65 rows=1 width=107)
   Index Cond: (o_totalprice = 10127.58)
```
Show table scan for high estimated result cardinality (1 expected row):
```sql
EXPLAIN SELECT *
FROM orders
WHERE o_totalprice BETWEEN 10000 AND 200000;
```
```
                                       QUERY PLAN                                       
----------------------------------------------------------------------------------------
 Seq Scan on orders  (cost=0.00..48595.00 rows=1022608 width=107)
   Filter: ((o_totalprice >= '10000'::numeric) AND (o_totalprice <= '200000'::numeric))
```
An index scan may have to access some pages multiple times. A bitmap index scan first identifies all relevant pages and accesses them only once.
However, it has higher upfront costs.
```sql
EXPLAIN SELECT *
FROM orders
WHERE o_totalprice BETWEEN 10000 AND 50000;
```
```
                                           QUERY PLAN                                            
-------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on orders  (cost=2641.64..31478.22 rows=182772 width=107)
   Recheck Cond: ((o_totalprice >= '10000'::numeric) AND (o_totalprice <= '50000'::numeric))
   ->  Bitmap Index Scan on orders_o_totalprice_idx  (cost=0.00..2595.95 rows=182772 width=0)
         Index Cond: ((o_totalprice >= '10000'::numeric) AND (o_totalprice <= '50000'::numeric))
```

##### Run time, actual cardinalities, buffer usage

Using the `ANALYZE` option, the query is actually executed, revealing actual (intermediate) result cardinalities as well as the optimization ('planning') and execution time.
```sql
EXPLAIN ANALYZE SELECT *
FROM orders
WHERE o_totalprice = 10127.58;
```
```
Index Scan using orders_o_totalprice_idx on orders  (cost=0.43..2.65 rows=1 width=107) (actual time=2.283..2.286 rows=1 loops=1)
   Index Cond: (o_totalprice = 10127.58)
 Planning Time: 0.253 ms
 Execution Time: 2.338 ms
```
The `BUFFERS` option in `EXPLAIN ANALYZE` reveals further execution details.
We can, for example, inspect how many pages were already present in the buffer cache ('shared hit') and how many were read from disk or the operating system cache ('read').
```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT *
FROM orders
WHERE o_totalprice BETWEEN 10000 AND 200000;
```
```
                                                     QUERY PLAN                                                     
--------------------------------------------------------------------------------------------------------------------
 Seq Scan on orders  (cost=0.00..48595.00 rows=1022608 width=107) (actual time=0.193..178.155 rows=1019277 loops=1)
   Filter: ((o_totalprice >= '10000'::numeric) AND (o_totalprice <= '200000'::numeric))
   Rows Removed by Filter: 480723
   Buffers: shared hit=193 read=25902
 Planning Time: 0.281 ms
 Execution Time: 201.388 ms
```

#### Buffer cache inspection

The extension [`pg_buffercache`](https://www.postgresql.org/docs/current/pgbuffercache.html) enables an inspection of shared buffer states:

```sql
CREATE EXTENSION pg_buffercache;
SELECT * FROM pg_buffercache LIMIT 5;
```
```
 bufferid | relfilenode | reltablespace | reldatabase | relforknumber | relblocknumber | isdirty | usagecount | pinning_backends 
----------+-------------+---------------+-------------+---------------+----------------+---------+------------+------------------
        1 |        1262 |          1664 |           0 |             0 |              0 | f       |          5 |                0
        2 |        1260 |          1664 |           0 |             0 |              0 | f       |          5 |                0
        3 |        1259 |          1663 |       16817 |             0 |              0 | f       |          5 |                0
        4 |        1259 |          1663 |       16817 |             0 |              1 | f       |          5 |                0
        5 |        1259 |          1663 |       16817 |             0 |              2 | f       |          5 |                0
```

We can query (1) statistics about used, dirty, and pinned pages:
```sql
SELECT 
    COUNT(*) AS total_buffers,
    SUM(CASE WHEN relfilenode IS NOT NULL THEN 1 ELSE 0 END) AS used_buffers,
    SUM(CASE WHEN relfilenode IS NULL THEN 1 ELSE 0 END) AS empty_buffers,
    SUM(CASE WHEN isdirty THEN 1 ELSE 0 END) AS dirty_buffers,
    SUM(CASE WHEN pinning_backends > 0 THEN 1 ELSE 0 END) AS pinned_buffers
FROM pg_buffercache;
```
```
 total_buffers | used_buffers | empty_buffers | dirty_buffers | pinned_buffers 
---------------+--------------+---------------+---------------+----------------
         16384 |          788 |         15596 |             1 |              0
```

... and (2) for which relation there are currently most cached pages:
```sql
SELECT n.nspname, c.relname, count(*) AS buffers
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
JOIN pg_namespace n ON n.oid = c.relnamespace
GROUP BY n.nspname, c.relname
ORDER BY 3 DESC LIMIT 5;
```
```
  nspname   |             relname             | buffers 
------------+---------------------------------+---------
 public     | orders                          |     226
 pg_catalog | pg_attribute                    |     147
 pg_catalog | pg_class                        |      69
 pg_catalog | pg_attribute_relid_attnum_index |      37
 pg_catalog | pg_amproc                       |      25
```

Using the pg_buffercache extension, we can, for example, show (1) how scanning large tables increases the corresponding buffer usage and (2) dirty and pinned pages for data modification queries and uncommitted transactions, respectively. 

#### Inspect transaction effects

We create a table `student` for showing effects: 
```sql
DROP TABLE IF EXISTS student;
CREATE TABLE student (
    student_id SERIAL PRIMARY KEY,
    name VARCHAR(50),
    phone_number VARCHAR(20)
);
INSERT INTO student VALUES(1, 'Sarah', '0815');
SELECT ctid, student_id, name, phone_number FROM student;
```
```
 ctid  | student_id | name  | phone_number 
-------+------------+-------+--------------
 (0,1) |          1 | Sarah | 0815
```
Update a tuple's field and inspect the table with the tuple identifier.
```sql
UPDATE student SET phone_number = '42' WHERE student_id = 1 ;
UPDATE student SET phone_number = '17' WHERE student_id = 1;
SELECT ctid, student_id, name, phone_number FROM student;
```
```
 ctid  | student_id | name  | phone_number 
-------+------------+-------+--------------
 (0,3) |          1 | Sarah | 17
```
Now, inspect the heap page with the MVCC information.
```sql
SELECT lp, t_xmin, t_xmax, t_ctid
FROM heap_page_items(get_raw_page('student', 0));
```
```
 lp | t_xmin | t_xmax | t_ctid 
----+--------+--------+--------
  1 | 146477 | 146478 | (0,2)
  2 | 146478 | 146479 | (0,3)
  3 | 146479 |      0 | (0,3)
```

#### Inspect running transactions and row locks
So far, we used auto-commit.
To inspect running/active transactions, we begin a transaction:
```sql
BEGIN TRANSACTION;
demo_db_internals=*# UPDATE student SET phone_number = '0405' WHERE student_id = 1;
```
And inspect currently running transactions **from another `psql` shell** using [`pg_stat_activity`](https://www.postgresql.org/docs/17/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW) view:
```sql
SELECT 
    pid, 
    usename, 
    state, 
    query_start, 
    now() - query_start AS duration, 
    query 
FROM pg_stat_activity 
WHERE state IN ('active', 'idle in transaction')
ORDER BY query_start;
```
```
  pid  | usename |        state        |          query_start          |    duration     |                             query                              
-------+---------+---------------------+-------------------------------+-----------------+----------------------------------------------------------------
 48345 | wieso   | idle in transaction | 2025-03-29 13:14:22.717196+01 | 00:02:49.874883 | UPDATE student SET phone_number = '0405' WHERE student_id = 1;
 48303 | wieso   | active              | 2025-03-29 13:17:12.592079+01 | 00:00:00        | SELECT                                                        +
       |         |                     |                               |                 |     pid,                                                      +
       |         |                     |                               |                 |     usename,                                                  +
       |         |                     |                               |                 |     state,                                                    +
       |         |                     |                               |                 |     query_start,                                              +
       |         |                     |                               |                 |     now() - query_start AS duration,                          +
       |         |                     |                               |                 |     query                                                     +
       |         |                     |                               |                 | FROM pg_stat_activity                                         +
       |         |                     |                               |                 | WHERE state IN ('active', 'idle in transaction')              +
       |         |                     |                               |                 | ORDER BY query_start;

```

Inspect the locked rows of the `student` table using the [`pgrowlocks`](https://www.postgresql.org/docs/current/pgrowlocks.html) module:
```sql
CREATE extension pgrowlocks;
SELECT locked_row, locker, modes FROM pgrowlocks('student');
```
```
 locked_row | locker |       modes       
------------+--------+-------------------
 (0,3)      | 146487 | {"No Key Update"}
```

If we execute `COMMIT TRANSACTION;` in the first shell, we see that the row is not locked anymore.

```sql
SELECT locked_row, locker, modes FROM pgrowlocks('student');
```
```
 locked_row | locker | modes 
------------+--------+-------
(0 rows)
```


We can also inspect the corresponding buffer entry (it may ('t') or may not ('f') be dirty):
```sql
SELECT 
    bufferid,
    usagecount,
    isdirty,
    pinning_backends,
    pg_class.relfilenode as relfilenode,
    relblocknumber,
    relname
FROM pg_buffercache
JOIN pg_class ON pg_buffercache.relfilenode = pg_class.relfilenode
WHERE pg_class.relname = 'student';
```
```
 bufferid | usagecount | isdirty | pinning_backends | relfilenode | relblocknumber | relname 
----------+------------+---------+------------------+-------------+----------------+---------
     1113 |          5 | t       |                0 |    17843856 |              0 | student
```


#### WAL (write-ahead log) inspection

We can use the [`pg_walinspect`](https://www.postgresql.org/docs/17/pgwalinspect.html) module to inspect the write-ahead log.

#### Process inspection
Inspect PostgreSQL processes:
```sql
SELECT pid, query, backend_type FROM pg_stat_activity;
```
```
  pid  |                         query                          |         backend_type         
-------+--------------------------------------------------------+------------------------------
 38934 |                                                        | autovacuum launcher
 38936 |                                                        | logical replication launcher
 48303 | SELECT pid, query, backend_type FROM pg_stat_activity; | client backend
 38932 |                                                        | background writer
 38931 |                                                        | checkpointer
 38933 |                                                        | walwriter
```

#### Client communication

Database systems are usually run as server applications, where clients can connect to.
The common way to communicate for PostgreSQL is using the wire protocol on top of TCP.
PostgreSQL uses the default port 5432 and implements a custom messaging protocol.
After initializing the connection (including startup messages, authentication, and others), SQL queries from the user and result tables are encoded in tagged messages.
The PostgreSQL wire format is also used for other newer systems and a typical application-level protocol on TCP.
For education purposes, it is valuable to understand that the default result table format is not engineered for large data transfers.
Noteworthy, PostgreSQL's optimizers query execution costs do not include conversion and transmission to client, which can become the bottleneck of queries.
The exchanged messages can be observed, for example, with [Wireshark](https://www.wireshark.org/):

- Open `Wireshark`
- Select the network interface (e.g., Loopback)
- Start observing by clicking the "Start capturing packets" button (the shark fin icon)
- Filter by PostgreSQL protocol: `pgsql`

Connect to a PostgreSQL server via `psql` and the loopback (which is not the default)
```
psql -h 127.0.0.1 -d demo_db_internals
```
Wireshark screenshot, showing the transmitted query:

<img src="https://github.com/klauck/demo_dbs_internal/blob/main/figures/wireshark_screenshot.png" width="900" />


## Attribution

The demonstrations are inspired, enabled, and partly adopted from existing write-ups and PostgreSQL extensions: without the previously publicly available material, collecting, designing, and engineering the demonstrations would have been more tedious.

**Sources for PostgreSQL internals:**

- Hironobu Suzuki: The Internals of PostgreSQL. https://www.interdb.jp/pg/. Accessed: 2025-05-09.
- The PostgreSQL Global Development Group: PostgreSQL 17 Documentation. https://www.postgresql.org/docs/17/index.html. Accessed: 2025-03-27.
- Egor Rogov: PostgreSQL 14 Internals. (2023) https://postgrespro.com/community/books/internals. Accessed: 2025-05-09.




## License

 <p xmlns:cc="http://creativecommons.org/ns#" xmlns:dct="http://purl.org/dc/terms/"><span property="dct:title">The collection "Hands-On PostgreSQL Demonstrations for Teaching and Learning Database System Internals"</span> by <span property="cc:attributionName">Stefan Halfpap</span> is licensed under <a href="https://creativecommons.org/licenses/by/4.0/?ref=chooser-v1" target="_blank" rel="license noopener noreferrer" style="display:inline-block;">CC BY 4.0<img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/cc.svg?ref=chooser-v1" alt=""><img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/by.svg?ref=chooser-v1" alt=""></a></p>
