# Demonstrations for Teaching and Learning Database System Internals

We present a collection of demonstrations for teaching and learning database system internals using PostgreSQL.

## Demonstrations per Lecture Topic

| Lecture Topic                | Suitable Demonstrations                                                                               |
|:----------------------------:|-------------------------------------------------------------------------------------------------------|
| Database Representation      | File organization <br> (Slotted) Page structure <br> Tuple representation                             |
| Caching                      | Buffer inspection                                                                                     | 
| Indexing                     | Index representation on disk <br> Index utilization (sequential scan vs. index scan vs. bitmap scan)  | 
| Query Execution              | Physical query plan <br> Buffer usage                                                                 | 
| Query Optimization           | Statistics <br> Cardinality estimation <br> Cost model <br> Query plan inspection                     | 
| Concurrency Control          | Inspect running transaction <br> Inspect MVCC columns <br> Row locking                                | 
| Recovery                     | Inspect running transaction <br> Inspect the write-ahead log                                          | 
