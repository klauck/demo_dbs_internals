# Demonstrations for Teaching and Learning Database System Internals

We present a collection of demonstrations for teaching and learning database system internals using PostgreSQL.
The demonstrations cover key aspects of the database representation on disk and query processing, visualized in the following graphic.

<img src="https://github.com/klauck/demo_dbs_internal/blob/main/demonstrated_database_system_internals.png" width="600" />

## Demonstrations per Lecture Topic
The demonstrations can be directly integrated into lectures about database system internals, for example, by switching between slide presentations giving background and hands-on demonstrations using PostgreSQL’s command line tool psql. We list common lecture topics and suitable demonstrations in the following table.

| Lecture Topic                | Suitable Demonstrations                                                                               |
|:----------------------------:|-------------------------------------------------------------------------------------------------------|
| Database Representation      | File organization <br> (Slotted) Page structure <br> Tuple representation                             |
| Caching                      | Buffer inspection                                                                                     | 
| Indexing                     | Index representation on disk <br> Index utilization (sequential scan vs. index scan vs. bitmap scan)  | 
| Query Execution              | Physical query plan <br> Buffer usage                                                                 | 
| Query Optimization           | Statistics <br> Cardinality estimation <br> Cost model <br> Query plan inspection                     | 
| Concurrency Control          | Inspect running transactions <br> Inspect MVCC columns <br> Row locking                                | 
| Recovery                     | Inspect running transactions <br> Inspect the write-ahead log                                          | 


## Demonstrations

### Setup



### Database Representation on Disk

#### Settings

The view `pg_settings` provides access to PostgreSQL’s configuration settings, including parameter names (`name`), current values (`setting`), and units (`unit`). We can use the `SHOW` and `SET` command to display and change individual (e.g., `SHOW name`) or all (e.g., `SHOW ALL`) configuration parameters.

#### File organization

Show the directory in which PostgreSQL stores its configuration and data (e.g., tables, indexes) files.

```
SELECT setting FROM pg_settings WHERE name = 'data_directory';
```

```
          setting           
----------------------------
 /opt/homebrew/var/postgres
```

Within this directory, there is a subdirectory for every database, which groups a set of tables.
Each database has an assigned OID (Object Identifier), which can be queried:

```
SELECT oid FROM pg_database WHERE datname = 'demo_db_internals';
```
```
   oid    
----------
 17843524
```
Inside the database subdirectory, data files (e.g., for specific tables) are stored.
The following query returns the file name for the `region` table:

```
SELECT relfilenode FROM pg_class WHERE relname='region';
```
```
 relfilenode 
-------------
       16821
```

The `region` table is, thus, stored in the file `/opt/homebrew/var/postgres/base/17843524/16821`.

Or we can directly query the file path for a relation based on the PostgreSQL directory:

```
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

We can examine the internal structure of a page using the `pageinspect` extension. 

##### Heap file

Inspect the page header of the `region` table's first block

```
CREATE EXTENSION pageinspect;
SELECT * FROM page_header(get_raw_page('region', 0));
```
```
    lsn    | checksum | flags | lower | upper | special | pagesize | version | prune_xid 
-----------+----------+-------+-------+-------+---------+----------+---------+-----------
 0/1B67540 |        0 |     0 |    44 |  7568 |    8192 |     8192 |       4 |         0
```

based on the header data, we can determine (1) how much space is left on the page (upper-lower) and (2) how many tuples ((lower-header_size)/pointer_size = (44 − 24)/4 = 5)
are stored on the page.

#### Tuple representation

We can also inspect individual tuples stored per page, including the linepointers (`lp`), byte offsets (`lp_off`), and MVCC information (`t_xmin`, `t_xmax`, `t_ctid`):

```
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

```
SELECT reltuples, relpages FROM pg_class WHERE relname = 'nation';
```

```
 reltuples | relpages 
-----------+----------
        25 |        1
```

Attribute-level statistics can be queried using the view `pg_stats`:

```
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
```
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
```
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

The well-known `EXPLAIN` command offers outputs in different format (i.e., `TEXT`, `JSON`, `XML`, `YAML`) and exposes total execution costs (`cost`), estimated cardinalities (`rows`), and information per operator.
```
EXPLAIN SELECT * FROM nation WHERE n_regionkey=4;
```

```
                       QUERY PLAN                       
--------------------------------------------------------
 Seq Scan on nation  (cost=0.00..1.31 rows=5 width=109)
   Filter: (n_regionkey = 4)
```
PostgreSQL does not expose a detailed cost break-down to the user (only per operator).
For simple queries, the estimated costs can be explained with the available documentation.
For example, the costs (1.31 ≈ 1.3125 = 1 * 1.0 + 25 * 0.01 + 25 * 0.0025) for the query are composed of costs for sequentially scanning all table's pages (1 * `seq_page_cost`), accessing all table's tuples (25 * `cpu_tuple_cost`), and operations on all table's tuples operator costs (25 * `cpu_operator_cost`)

Recap, we can query current [settings](#settings):

```
SHOW seq_page_cost;
```
```
 seq_page_cost 
---------------
 1
```
```
SHOW cpu_tuple_cost;
```
```
 cpu_tuple_cost 
----------------
 0.01
```
```
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
```
CREATE INDEX ON orders(o_totalprice);
```

Show usage for low estimated result cardinality (1 expected row):
```
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
```
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
Index scan may have to access some page multiple times. Bitmap index scan scans first identify relevent pages and access them only once.
However, they have higher 
```
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
```
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
```
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

```
CREATE EXTENSION pg_buffercache;
SELECT * FROM pg_buffercache LIMIT 5;
```
```
SELECT * FROM pg_buffercache LIMIT 5;
 bufferid | relfilenode | reltablespace | reldatabase | relforknumber | relblocknumber | isdirty | usagecount | pinning_backends 
----------+-------------+---------------+-------------+---------------+----------------+---------+------------+------------------
        1 |        1262 |          1664 |           0 |             0 |              0 | f       |          5 |                0
        2 |        1260 |          1664 |           0 |             0 |              0 | f       |          5 |                0
        3 |        1259 |          1663 |       16817 |             0 |              0 | f       |          5 |                0
        4 |        1259 |          1663 |       16817 |             0 |              1 | f       |          5 |                0
        5 |        1259 |          1663 |       16817 |             0 |              2 | f       |          5 |                0
```

We can query (1) statistics about used, dirty, and pinned pages:
```
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
```
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

#### Inspect running transactions

#### Row lock inspection

#### WAL (write-ahead log) inspection

#### Process inspection

#### Client communication
