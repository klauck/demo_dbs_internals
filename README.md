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

#### Page structure

##### Heap file

##### Index file


#### Tuple representation



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
