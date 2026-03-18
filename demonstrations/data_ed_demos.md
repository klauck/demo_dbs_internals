# Demonstrations for DataEd Presentation


## psql

### Setup

```sql
CREATE EXTENSION IF NOT EXISTS pageinspect;
DROP TABLE IF EXISTS student;
CREATE TABLE student (
    student_id INTEGER PRIMARY KEY,
    name VARCHAR(50),
    phone_number VARCHAR(20)
);
INSERT INTO student VALUES(1, 'Sarah', '0815');
```



### Commands


```sql
\d
```

```sql
SHOW data_directory;
```

```sql
SELECT pg_relation_filepath('lineitem');
```

```sql
SELECT pg_relation_filepath('student');
```

```sql
SELECT * FROM student;
```

```sql
\d+
```

```sql
SELECT * FROM page_header(get_raw_page('student', 0));
```

```sql
INSERT INTO student VALUES(2, 'Jin', '1704');
```

```sql
SELECT * FROM page_header(get_raw_page('student', 0));
```

```sql
SELECT ctid, student_id, name, phone_number FROM student;
```

## PGlite

### Setup

```sql
CREATE EXTENSION IF NOT EXISTS pageinspect;
DROP TABLE IF EXISTS student;
CREATE TABLE student (
    student_id INTEGER PRIMARY KEY,
    name VARCHAR(50),
    phone_number VARCHAR(20)
);
INSERT INTO student VALUES(1, 'Sarah', '0815');
SELECT ctid, student_id, name, phone_number FROM student;
```

### Commands

```sql
UPDATE student SET phone_number = '1704' WHERE student_id = 1;
```

```sql
UPDATE student SET phone_number = '42' WHERE student_id = 1;
```

```sql
SELECT * FROM student;
```

```sql
SELECT ctid, student_id, name, phone_number FROM student;
```

```sql
SELECT lp, t_xmin, t_xmax, t_ctid, t_data
FROM heap_page_items(get_raw_page('student', 0));
```



