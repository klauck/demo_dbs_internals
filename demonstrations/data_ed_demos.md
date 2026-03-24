# Demonstrations for the DataEd'26 Presentation


## psql

### Setup

Executed before the presentation.

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

Show user tables:

```sql
\d
```

Show table contents:

```sql
SELECT * FROM student;
```

Show the directory in which PostgreSQL stores its data:

```sql
SHOW data_directory;
```

Show the file path for a table:

```sql
SELECT pg_relation_filepath('student');
```

Show a page header (page 0):

```sql
SELECT * FROM page_header(get_raw_page('student', 0));
```

Insert a new tuple:

```sql
INSERT INTO student VALUES(2, 'Jin', '1704');
```

Show the page header after the insert (reduced free space):

```sql
SELECT * FROM page_header(get_raw_page('student', 0));
```

Show table contents after insert, including tuple locations (page_id, line_pointer)

```sql
SELECT ctid, student_id, name, phone_number FROM student;
```

## PGlite

https://pglite.dev/repl/

Used for the PGlite screenshot.

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



