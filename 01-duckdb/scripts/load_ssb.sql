-- Deterministic SSB load for DuckDB.
--
-- Why this file exists: `read_csv_auto` infers column types from a sample, and
-- the inferred types differ between our two copies of the data. That changes
-- measured latency by up to 10x, because materialising a VARCHAR/DATE column to
-- CSV costs far more than materialising a BIGINT. It also silently breaks the
-- date join: on the ssb-dbgen copy `lineorder.orderdate` infers as DATE while
-- `date.datekey` infers as BIGINT, and the join then fails with
--   Conversion Error: Unimplemented type for cast (BIGINT -> DATE)
--
-- Declaring every type removes both problems and makes the two sources produce
-- identical tables.
--
-- Usage - pick the section matching your copy of the data, and substitute the
-- directory:
--
--   duckdb ssb.duckdb
--   .read load_ssb.sql
--
-- The two copies differ in delimiter and in how orderdate/commitdate are
-- written:
--   /p/pd/pim/sf*        '|' separated, dates as integers   19960130
--   /p/pd/ssb-dbgen/sf*  ',' separated, dates as ISO strings "1996-01-30"
-- Both are normalised below to the integer YYYYMMDD form the SSB queries expect,
-- so `lineorder.orderdate = date.datekey` joins in either case.

-- ---------------------------------------------------------------------------
-- This file is a TEMPLATE. __DIR__ and __SEP__ are substituted by load_ssb.sh,
-- which is the supported way to run it:
--
--   bash load_ssb.sh /p/pd/ssb-dbgen/sf1 ssb_sf1.duckdb
--
-- Substitution is used rather than DuckDB variables because `getvariable` does
-- not exist in v0.8.0, and this must load identically under both versions.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Dimension tables. Identical in both copies apart from the delimiter.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE customer AS
SELECT * FROM read_csv('__DIR__/customer.tbl',
    delim = '__SEP__', header = false, ignore_errors = true,
    columns = {
      'custkey': 'BIGINT', 'name': 'VARCHAR', 'address': 'VARCHAR',
      'city': 'VARCHAR', 'nation': 'VARCHAR', 'region': 'VARCHAR',
      'phone': 'VARCHAR', 'mktsegment': 'VARCHAR'
    });

-- part.tbl contains unbalanced quotes in some rows; quote='' disables quote
-- handling so the parse does not swallow field boundaries.
CREATE OR REPLACE TABLE part AS
SELECT * FROM read_csv('__DIR__/part.tbl',
    delim = '__SEP__', header = false, ignore_errors = true, quote = '',
    columns = {
      'partkey': 'BIGINT', 'name': 'VARCHAR', 'mfgr': 'VARCHAR',
      'category': 'VARCHAR', 'brand1': 'VARCHAR', 'color': 'VARCHAR',
      'type': 'VARCHAR', 'size': 'BIGINT', 'container': 'VARCHAR'
    });

CREATE OR REPLACE TABLE supplier AS
SELECT * FROM read_csv('__DIR__/supplier.tbl',
    delim = '__SEP__', header = false, ignore_errors = true,
    columns = {
      'suppkey': 'BIGINT', 'name': 'VARCHAR', 'address': 'VARCHAR',
      'city': 'VARCHAR', 'nation': 'VARCHAR', 'region': 'VARCHAR',
      'phone': 'VARCHAR'
    });

-- datekey is an integer YYYYMMDD in both copies.
CREATE OR REPLACE TABLE date AS
SELECT * FROM read_csv('__DIR__/date.tbl',
    delim = '__SEP__', header = false, ignore_errors = true,
    columns = {
      'datekey': 'BIGINT', 'date': 'VARCHAR', 'dayofweek': 'VARCHAR',
      'month': 'VARCHAR', 'year': 'BIGINT', 'yearmonthnum': 'BIGINT',
      'yearmonth': 'VARCHAR', 'daynuminweek': 'BIGINT',
      'daynuminmonth': 'BIGINT', 'daynuminyear': 'BIGINT',
      'monthnuminyear': 'BIGINT', 'weeknuminyear': 'BIGINT',
      'sellingseason': 'VARCHAR', 'lastdayinweekfl': 'VARCHAR',
      'lastdayinmonthfl': 'VARCHAR', 'holidayfl': 'VARCHAR',
      'weekdayfl': 'VARCHAR'
    });
-- NOTE: the date table has SEVENTEEN columns. d_daynuminmonth sits between
-- d_daynuminweek and d_daynuminyear and is easy to miss. Declaring sixteen
-- makes every row fail to parse, and with ignore_errors=true the table loads
-- silently EMPTY rather than raising - which then makes every SSB query return
-- no rows in a few milliseconds and look merely "fast".

-- ---------------------------------------------------------------------------
-- lineorder. Read the date columns as VARCHAR, then normalise to integer
-- YYYYMMDD, which works whether the file holds 19960130 or "1996-01-30".
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE lineorder AS
SELECT
    orderkey, linenumber, custkey, partkey, suppkey,
    CAST(replace(orderdate,  '-', '') AS BIGINT) AS orderdate,
    orderpriority, shippriority, quantity, extendedprice, ordtotalprice,
    discount, revenue, supplycost, tax,
    CAST(replace(commitdate, '-', '') AS BIGINT) AS commitdate,
    shipmode
FROM read_csv('__DIR__/lineorder.tbl',
    delim = '__SEP__', header = false, ignore_errors = true,
    columns = {
      'orderkey': 'BIGINT', 'linenumber': 'BIGINT', 'custkey': 'BIGINT',
      'partkey': 'BIGINT', 'suppkey': 'BIGINT', 'orderdate': 'VARCHAR',
      'orderpriority': 'VARCHAR', 'shippriority': 'VARCHAR',
      'quantity': 'BIGINT', 'extendedprice': 'BIGINT',
      'ordtotalprice': 'BIGINT', 'discount': 'BIGINT', 'revenue': 'BIGINT',
      'supplycost': 'BIGINT', 'tax': 'BIGINT', 'commitdate': 'VARCHAR',
      'shipmode': 'VARCHAR'
    });

-- ---------------------------------------------------------------------------
-- Sanity checks. The date join must return the full lineorder row count; if it
-- returns 0 or errors, the types did not come out right.
-- ---------------------------------------------------------------------------
SELECT 'lineorder' AS t, count(*) AS n FROM lineorder
UNION ALL SELECT 'customer', count(*) FROM customer
UNION ALL SELECT 'part',     count(*) FROM part
UNION ALL SELECT 'supplier', count(*) FROM supplier
UNION ALL SELECT 'date',     count(*) FROM date
UNION ALL SELECT 'date join', count(*) FROM lineorder l JOIN date d
                              ON l.orderdate = d.datekey;
