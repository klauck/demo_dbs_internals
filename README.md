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

From the header data, we determine (1) how much space is left on the page (upper-lower) and (2) how many tuples ((lower-header_size)/pointer_size = (44 − 24)/4 = 5)
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

#### Query plan inspection

##### Index utilization (sequential scan vs. index scan vs. bitmap scan)

##### Run time, actual cardinalities, buffer usage


#### Buffer cache inspection

#### Inspect running transactions

#### Row lock inspection

#### WAL (write-ahead log) inspection

#### Process inspection

#### Client communication
