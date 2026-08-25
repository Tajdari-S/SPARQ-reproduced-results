#!/bin/bash

# Default number of runs per query
NUM_RUNS=5

# Check if duckdb is installed
if ! command -v ../duckdb &> /dev/null; then
    echo "Error: duckdb is not installed or not in PATH"
    exit 1
fi

# Create timestamp for the profiling session
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="duckdb_profiles_cougar_${TIMESTAMP}"
mkdir -p "$OUTPUT_DIR"

echo "Starting profiling session at ${TIMESTAMP}"
echo "Output will be stored in ${OUTPUT_DIR}"

# Start a single DuckDB instance and feed all commands
../duckdb <<EOF
    -- Setup commands (executed once)
    CREATE TABLE date AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/date.tbl');
    CREATE TABLE customer AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/customer.tbl');
    CREATE TABLE lineorder AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/lineorder.tbl');
    CREATE TABLE part AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/part.tbl');
    CREATE TABLE supplier AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/supplier.tbl');
    
    ALTER TABLE customer RENAME column0 TO custkey; ALTER TABLE customer RENAME column1 TO name; ALTER TABLE customer RENAME column2 TO address; ALTER TABLE customer RENAME column3 TO city; ALTER TABLE customer RENAME column4 TO nation; ALTER TABLE customer RENAME column5 TO region; ALTER TABLE customer RENAME column6 TO phone; ALTER TABLE customer RENAME column7 TO mktsegment;
    ALTER TABLE lineorder RENAME column00 TO orderkey; ALTER TABLE lineorder RENAME column01 TO linenumber; ALTER TABLE lineorder RENAME column02 TO custkey; ALTER TABLE lineorder RENAME column03 TO partkey; ALTER TABLE lineorder RENAME column04 TO suppkey; ALTER TABLE lineorder RENAME column05 TO orderdate; ALTER TABLE lineorder RENAME column06 TO orderpriority; ALTER TABLE lineorder RENAME column07 TO shippriority; ALTER TABLE lineorder RENAME column08 TO quantity; ALTER TABLE lineorder RENAME column09 TO extendedprice; ALTER TABLE lineorder RENAME column10 TO ordtotalprice; ALTER TABLE lineorder RENAME column11 TO discount; ALTER TABLE lineorder RENAME column12 TO revenue; ALTER TABLE lineorder RENAME column13 TO supplycost; ALTER TABLE lineorder RENAME column14 TO tax; ALTER TABLE lineorder RENAME column15 TO commitdate; ALTER TABLE lineorder RENAME column16 TO shipmode;
    ALTER TABLE part RENAME column0 TO partkey; ALTER TABLE part RENAME column1 TO name; ALTER TABLE part RENAME column2 TO mfgr; ALTER TABLE part RENAME column3 TO category; ALTER TABLE part RENAME column4 TO brand1; ALTER TABLE part RENAME column5 TO color; ALTER TABLE part RENAME column6 TO type; ALTER TABLE part RENAME column7 TO size; ALTER TABLE part RENAME column8 TO container;
    ALTER TABLE supplier RENAME column0 TO suppkey; ALTER TABLE supplier RENAME column1 TO name; ALTER TABLE supplier RENAME column2 TO address; ALTER TABLE supplier RENAME column3 TO city; ALTER TABLE supplier RENAME column4 TO nation; ALTER TABLE supplier RENAME column5 TO region; ALTER TABLE supplier RENAME column6 TO phone;
    ALTER TABLE date RENAME column00 TO datekey; ALTER TABLE date RENAME column01 TO date; ALTER TABLE date RENAME column02 TO dayofweek; ALTER TABLE date RENAME column03 TO month; ALTER TABLE date RENAME column04 TO year; ALTER TABLE date RENAME column05 TO yearmonthnum; ALTER TABLE date RENAME column06 TO yearmonth; ALTER TABLE date RENAME column07 TO daynuminweek; ALTER TABLE date RENAME column08 TO daynuminmonth; ALTER TABLE date RENAME column09 TO daynuminyear; ALTER TABLE date RENAME column10 TO monthnuminyear; ALTER TABLE date RENAME column11 TO weeknuminyear; ALTER TABLE date RENAME column12 TO sellingseason; ALTER TABLE date RENAME column13 TO lastdayinweekfl; ALTER TABLE date RENAME column14 TO lastdayinmonthfl; ALTER TABLE date RENAME column15 TO holidayfl; ALTER TABLE date RENAME column16 TO weekdayfl;
    
    #PRAGMA enable_profiling='json';
    #PRAGMA enable_profiling='query_tree';
    #PRAGMA enable_profiling='query_tree_optimizer';
    PRAGMA enable_profiling='json';
    PRAGMA profiling_mode='detailed';
    PRAGMA custom_profiling_settings='{"CPU_TIME": "true", "EXTRA_INFO": "true", "OPERATOR_CARDINALITY": "true", "OPERATOR_TIMING": "true", "BLOCKED_THREAD_TIME": "true", "LATENCY": "true", "OPERATOR_ROWS_SCANNED": "true", "RESULT_SET_SIZE": "true", "ROWS_RETURNED": "true"}';

    -- Queries (each run 5 times within the same instance)
    $(for i in {1..5}; do printf "PRAGMA profiling_output = './${OUTPUT_DIR}/Query_1.1_run%02d.json'; select sum(lineorder.extendedprice*lineorder.discount) as revenue from lineorder, date where lineorder.orderdate = date.datekey and year = 1993 and discount between 1 and 3 and quantity < 25;\n" $i; done)
EOF

../duckdb <<EOF
    -- Setup commands (executed once)
    CREATE TABLE date AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/date.tbl');
    CREATE TABLE customer AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/customer.tbl');
    CREATE TABLE lineorder AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/lineorder.tbl');
    CREATE TABLE part AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/part.tbl');
    CREATE TABLE supplier AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/supplier.tbl');
    
    ALTER TABLE customer RENAME column0 TO custkey; ALTER TABLE customer RENAME column1 TO name; ALTER TABLE customer RENAME column2 TO address; ALTER TABLE customer RENAME column3 TO city; ALTER TABLE customer RENAME column4 TO nation; ALTER TABLE customer RENAME column5 TO region; ALTER TABLE customer RENAME column6 TO phone; ALTER TABLE customer RENAME column7 TO mktsegment;
    ALTER TABLE lineorder RENAME column00 TO orderkey; ALTER TABLE lineorder RENAME column01 TO linenumber; ALTER TABLE lineorder RENAME column02 TO custkey; ALTER TABLE lineorder RENAME column03 TO partkey; ALTER TABLE lineorder RENAME column04 TO suppkey; ALTER TABLE lineorder RENAME column05 TO orderdate; ALTER TABLE lineorder RENAME column06 TO orderpriority; ALTER TABLE lineorder RENAME column07 TO shippriority; ALTER TABLE lineorder RENAME column08 TO quantity; ALTER TABLE lineorder RENAME column09 TO extendedprice; ALTER TABLE lineorder RENAME column10 TO ordtotalprice; ALTER TABLE lineorder RENAME column11 TO discount; ALTER TABLE lineorder RENAME column12 TO revenue; ALTER TABLE lineorder RENAME column13 TO supplycost; ALTER TABLE lineorder RENAME column14 TO tax; ALTER TABLE lineorder RENAME column15 TO commitdate; ALTER TABLE lineorder RENAME column16 TO shipmode;
    ALTER TABLE part RENAME column0 TO partkey; ALTER TABLE part RENAME column1 TO name; ALTER TABLE part RENAME column2 TO mfgr; ALTER TABLE part RENAME column3 TO category; ALTER TABLE part RENAME column4 TO brand1; ALTER TABLE part RENAME column5 TO color; ALTER TABLE part RENAME column6 TO type; ALTER TABLE part RENAME column7 TO size; ALTER TABLE part RENAME column8 TO container;
    ALTER TABLE supplier RENAME column0 TO suppkey; ALTER TABLE supplier RENAME column1 TO name; ALTER TABLE supplier RENAME column2 TO address; ALTER TABLE supplier RENAME column3 TO city; ALTER TABLE supplier RENAME column4 TO nation; ALTER TABLE supplier RENAME column5 TO region; ALTER TABLE supplier RENAME column6 TO phone;
    ALTER TABLE date RENAME column00 TO datekey; ALTER TABLE date RENAME column01 TO date; ALTER TABLE date RENAME column02 TO dayofweek; ALTER TABLE date RENAME column03 TO month; ALTER TABLE date RENAME column04 TO year; ALTER TABLE date RENAME column05 TO yearmonthnum; ALTER TABLE date RENAME column06 TO yearmonth; ALTER TABLE date RENAME column07 TO daynuminweek; ALTER TABLE date RENAME column08 TO daynuminmonth; ALTER TABLE date RENAME column09 TO daynuminyear; ALTER TABLE date RENAME column10 TO monthnuminyear; ALTER TABLE date RENAME column11 TO weeknuminyear; ALTER TABLE date RENAME column12 TO sellingseason; ALTER TABLE date RENAME column13 TO lastdayinweekfl; ALTER TABLE date RENAME column14 TO lastdayinmonthfl; ALTER TABLE date RENAME column15 TO holidayfl; ALTER TABLE date RENAME column16 TO weekdayfl;
    
    #PRAGMA enable_profiling='json';
    #PRAGMA enable_profiling='query_tree';
    #PRAGMA enable_profiling='query_tree_optimizer';
    PRAGMA enable_profiling='json';
    PRAGMA profiling_mode='detailed';
    PRAGMA custom_profiling_settings='{"CPU_TIME": "true", "EXTRA_INFO": "true", "OPERATOR_CARDINALITY": "true", "OPERATOR_TIMING": "true", "BLOCKED_THREAD_TIME": "true", "LATENCY": "true", "OPERATOR_ROWS_SCANNED": "true", "RESULT_SET_SIZE": "true", "ROWS_RETURNED": "true"}';

    -- Queries (each run 5 times within the same instance)
    
    $(for i in {1..5}; do printf "PRAGMA profiling_output = './${OUTPUT_DIR}/Query_1.2_run%02d.json'; select sum(extendedprice*discount) as revenue from lineorder, date where orderdate = datekey and yearmonthnum = 199401 and discount between 4 and 6 and quantity between 26 and 35;\n" $i; done)
EOF

../duckdb <<EOF
    -- Setup commands (executed once)
    CREATE TABLE date AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/date.tbl');
    CREATE TABLE customer AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/customer.tbl');
    CREATE TABLE lineorder AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/lineorder.tbl');
    CREATE TABLE part AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/part.tbl');
    CREATE TABLE supplier AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/supplier.tbl');
    
    ALTER TABLE customer RENAME column0 TO custkey; ALTER TABLE customer RENAME column1 TO name; ALTER TABLE customer RENAME column2 TO address; ALTER TABLE customer RENAME column3 TO city; ALTER TABLE customer RENAME column4 TO nation; ALTER TABLE customer RENAME column5 TO region; ALTER TABLE customer RENAME column6 TO phone; ALTER TABLE customer RENAME column7 TO mktsegment;
    ALTER TABLE lineorder RENAME column00 TO orderkey; ALTER TABLE lineorder RENAME column01 TO linenumber; ALTER TABLE lineorder RENAME column02 TO custkey; ALTER TABLE lineorder RENAME column03 TO partkey; ALTER TABLE lineorder RENAME column04 TO suppkey; ALTER TABLE lineorder RENAME column05 TO orderdate; ALTER TABLE lineorder RENAME column06 TO orderpriority; ALTER TABLE lineorder RENAME column07 TO shippriority; ALTER TABLE lineorder RENAME column08 TO quantity; ALTER TABLE lineorder RENAME column09 TO extendedprice; ALTER TABLE lineorder RENAME column10 TO ordtotalprice; ALTER TABLE lineorder RENAME column11 TO discount; ALTER TABLE lineorder RENAME column12 TO revenue; ALTER TABLE lineorder RENAME column13 TO supplycost; ALTER TABLE lineorder RENAME column14 TO tax; ALTER TABLE lineorder RENAME column15 TO commitdate; ALTER TABLE lineorder RENAME column16 TO shipmode;
    ALTER TABLE part RENAME column0 TO partkey; ALTER TABLE part RENAME column1 TO name; ALTER TABLE part RENAME column2 TO mfgr; ALTER TABLE part RENAME column3 TO category; ALTER TABLE part RENAME column4 TO brand1; ALTER TABLE part RENAME column5 TO color; ALTER TABLE part RENAME column6 TO type; ALTER TABLE part RENAME column7 TO size; ALTER TABLE part RENAME column8 TO container;
    ALTER TABLE supplier RENAME column0 TO suppkey; ALTER TABLE supplier RENAME column1 TO name; ALTER TABLE supplier RENAME column2 TO address; ALTER TABLE supplier RENAME column3 TO city; ALTER TABLE supplier RENAME column4 TO nation; ALTER TABLE supplier RENAME column5 TO region; ALTER TABLE supplier RENAME column6 TO phone;
    ALTER TABLE date RENAME column00 TO datekey; ALTER TABLE date RENAME column01 TO date; ALTER TABLE date RENAME column02 TO dayofweek; ALTER TABLE date RENAME column03 TO month; ALTER TABLE date RENAME column04 TO year; ALTER TABLE date RENAME column05 TO yearmonthnum; ALTER TABLE date RENAME column06 TO yearmonth; ALTER TABLE date RENAME column07 TO daynuminweek; ALTER TABLE date RENAME column08 TO daynuminmonth; ALTER TABLE date RENAME column09 TO daynuminyear; ALTER TABLE date RENAME column10 TO monthnuminyear; ALTER TABLE date RENAME column11 TO weeknuminyear; ALTER TABLE date RENAME column12 TO sellingseason; ALTER TABLE date RENAME column13 TO lastdayinweekfl; ALTER TABLE date RENAME column14 TO lastdayinmonthfl; ALTER TABLE date RENAME column15 TO holidayfl; ALTER TABLE date RENAME column16 TO weekdayfl;
    
    #PRAGMA enable_profiling='json';
    #PRAGMA enable_profiling='query_tree';
    #PRAGMA enable_profiling='query_tree_optimizer';
    PRAGMA enable_profiling='json';
    PRAGMA profiling_mode='detailed';
    PRAGMA custom_profiling_settings='{"CPU_TIME": "true", "EXTRA_INFO": "true", "OPERATOR_CARDINALITY": "true", "OPERATOR_TIMING": "true", "BLOCKED_THREAD_TIME": "true", "LATENCY": "true", "OPERATOR_ROWS_SCANNED": "true", "RESULT_SET_SIZE": "true", "ROWS_RETURNED": "true"}';

    -- Queries (each run 5 times within the same instance)
    
    $(for i in {1..5}; do printf "PRAGMA profiling_output = './${OUTPUT_DIR}/Query_1.3_run%02d.json'; select sum(extendedprice*discount) as revenue from lineorder, date where orderdate = datekey and weeknuminyear = 6 and year = 1994 and discount between 5 and 7 and quantity between 26 and 35;\n" $i; done)
EOF

../duckdb <<EOF
    -- Setup commands (executed once)
    CREATE TABLE date AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/date.tbl');
    CREATE TABLE customer AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/customer.tbl');
    CREATE TABLE lineorder AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/lineorder.tbl');
    CREATE TABLE part AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/part.tbl');
    CREATE TABLE supplier AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/supplier.tbl');
    
    ALTER TABLE customer RENAME column0 TO custkey; ALTER TABLE customer RENAME column1 TO name; ALTER TABLE customer RENAME column2 TO address; ALTER TABLE customer RENAME column3 TO city; ALTER TABLE customer RENAME column4 TO nation; ALTER TABLE customer RENAME column5 TO region; ALTER TABLE customer RENAME column6 TO phone; ALTER TABLE customer RENAME column7 TO mktsegment;
    ALTER TABLE lineorder RENAME column00 TO orderkey; ALTER TABLE lineorder RENAME column01 TO linenumber; ALTER TABLE lineorder RENAME column02 TO custkey; ALTER TABLE lineorder RENAME column03 TO partkey; ALTER TABLE lineorder RENAME column04 TO suppkey; ALTER TABLE lineorder RENAME column05 TO orderdate; ALTER TABLE lineorder RENAME column06 TO orderpriority; ALTER TABLE lineorder RENAME column07 TO shippriority; ALTER TABLE lineorder RENAME column08 TO quantity; ALTER TABLE lineorder RENAME column09 TO extendedprice; ALTER TABLE lineorder RENAME column10 TO ordtotalprice; ALTER TABLE lineorder RENAME column11 TO discount; ALTER TABLE lineorder RENAME column12 TO revenue; ALTER TABLE lineorder RENAME column13 TO supplycost; ALTER TABLE lineorder RENAME column14 TO tax; ALTER TABLE lineorder RENAME column15 TO commitdate; ALTER TABLE lineorder RENAME column16 TO shipmode;
    ALTER TABLE part RENAME column0 TO partkey; ALTER TABLE part RENAME column1 TO name; ALTER TABLE part RENAME column2 TO mfgr; ALTER TABLE part RENAME column3 TO category; ALTER TABLE part RENAME column4 TO brand1; ALTER TABLE part RENAME column5 TO color; ALTER TABLE part RENAME column6 TO type; ALTER TABLE part RENAME column7 TO size; ALTER TABLE part RENAME column8 TO container;
    ALTER TABLE supplier RENAME column0 TO suppkey; ALTER TABLE supplier RENAME column1 TO name; ALTER TABLE supplier RENAME column2 TO address; ALTER TABLE supplier RENAME column3 TO city; ALTER TABLE supplier RENAME column4 TO nation; ALTER TABLE supplier RENAME column5 TO region; ALTER TABLE supplier RENAME column6 TO phone;
    ALTER TABLE date RENAME column00 TO datekey; ALTER TABLE date RENAME column01 TO date; ALTER TABLE date RENAME column02 TO dayofweek; ALTER TABLE date RENAME column03 TO month; ALTER TABLE date RENAME column04 TO year; ALTER TABLE date RENAME column05 TO yearmonthnum; ALTER TABLE date RENAME column06 TO yearmonth; ALTER TABLE date RENAME column07 TO daynuminweek; ALTER TABLE date RENAME column08 TO daynuminmonth; ALTER TABLE date RENAME column09 TO daynuminyear; ALTER TABLE date RENAME column10 TO monthnuminyear; ALTER TABLE date RENAME column11 TO weeknuminyear; ALTER TABLE date RENAME column12 TO sellingseason; ALTER TABLE date RENAME column13 TO lastdayinweekfl; ALTER TABLE date RENAME column14 TO lastdayinmonthfl; ALTER TABLE date RENAME column15 TO holidayfl; ALTER TABLE date RENAME column16 TO weekdayfl;
    
    #PRAGMA enable_profiling='json';
    #PRAGMA enable_profiling='query_tree';
    #PRAGMA enable_profiling='query_tree_optimizer';
    PRAGMA enable_profiling='json';
    PRAGMA profiling_mode='detailed';
    PRAGMA custom_profiling_settings='{"CPU_TIME": "true", "EXTRA_INFO": "true", "OPERATOR_CARDINALITY": "true", "OPERATOR_TIMING": "true", "BLOCKED_THREAD_TIME": "true", "LATENCY": "true", "OPERATOR_ROWS_SCANNED": "true", "RESULT_SET_SIZE": "true", "ROWS_RETURNED": "true"}';

    -- Queries (each run 5 times within the same instance)
    
    $(for i in {1..5}; do printf "PRAGMA profiling_output = './${OUTPUT_DIR}/Query_2.1_run%02d.json'; select sum(revenue), year, brand1 from lineorder, date, part, supplier where orderdate = datekey and lineorder.partkey = part.partkey and lineorder.suppkey = supplier.suppkey and category = 'MFGR#12' and region = 'AMERICA' group by year, brand1 order by year, brand1;\n" $i; done)
EOF
../duckdb <<EOF
    -- Setup commands (executed once)
    CREATE TABLE date AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/date.tbl');
    CREATE TABLE customer AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/customer.tbl');
    CREATE TABLE lineorder AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/lineorder.tbl');
    CREATE TABLE part AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/part.tbl');
    CREATE TABLE supplier AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/supplier.tbl');
    
    ALTER TABLE customer RENAME column0 TO custkey; ALTER TABLE customer RENAME column1 TO name; ALTER TABLE customer RENAME column2 TO address; ALTER TABLE customer RENAME column3 TO city; ALTER TABLE customer RENAME column4 TO nation; ALTER TABLE customer RENAME column5 TO region; ALTER TABLE customer RENAME column6 TO phone; ALTER TABLE customer RENAME column7 TO mktsegment;
    ALTER TABLE lineorder RENAME column00 TO orderkey; ALTER TABLE lineorder RENAME column01 TO linenumber; ALTER TABLE lineorder RENAME column02 TO custkey; ALTER TABLE lineorder RENAME column03 TO partkey; ALTER TABLE lineorder RENAME column04 TO suppkey; ALTER TABLE lineorder RENAME column05 TO orderdate; ALTER TABLE lineorder RENAME column06 TO orderpriority; ALTER TABLE lineorder RENAME column07 TO shippriority; ALTER TABLE lineorder RENAME column08 TO quantity; ALTER TABLE lineorder RENAME column09 TO extendedprice; ALTER TABLE lineorder RENAME column10 TO ordtotalprice; ALTER TABLE lineorder RENAME column11 TO discount; ALTER TABLE lineorder RENAME column12 TO revenue; ALTER TABLE lineorder RENAME column13 TO supplycost; ALTER TABLE lineorder RENAME column14 TO tax; ALTER TABLE lineorder RENAME column15 TO commitdate; ALTER TABLE lineorder RENAME column16 TO shipmode;
    ALTER TABLE part RENAME column0 TO partkey; ALTER TABLE part RENAME column1 TO name; ALTER TABLE part RENAME column2 TO mfgr; ALTER TABLE part RENAME column3 TO category; ALTER TABLE part RENAME column4 TO brand1; ALTER TABLE part RENAME column5 TO color; ALTER TABLE part RENAME column6 TO type; ALTER TABLE part RENAME column7 TO size; ALTER TABLE part RENAME column8 TO container;
    ALTER TABLE supplier RENAME column0 TO suppkey; ALTER TABLE supplier RENAME column1 TO name; ALTER TABLE supplier RENAME column2 TO address; ALTER TABLE supplier RENAME column3 TO city; ALTER TABLE supplier RENAME column4 TO nation; ALTER TABLE supplier RENAME column5 TO region; ALTER TABLE supplier RENAME column6 TO phone;
    ALTER TABLE date RENAME column00 TO datekey; ALTER TABLE date RENAME column01 TO date; ALTER TABLE date RENAME column02 TO dayofweek; ALTER TABLE date RENAME column03 TO month; ALTER TABLE date RENAME column04 TO year; ALTER TABLE date RENAME column05 TO yearmonthnum; ALTER TABLE date RENAME column06 TO yearmonth; ALTER TABLE date RENAME column07 TO daynuminweek; ALTER TABLE date RENAME column08 TO daynuminmonth; ALTER TABLE date RENAME column09 TO daynuminyear; ALTER TABLE date RENAME column10 TO monthnuminyear; ALTER TABLE date RENAME column11 TO weeknuminyear; ALTER TABLE date RENAME column12 TO sellingseason; ALTER TABLE date RENAME column13 TO lastdayinweekfl; ALTER TABLE date RENAME column14 TO lastdayinmonthfl; ALTER TABLE date RENAME column15 TO holidayfl; ALTER TABLE date RENAME column16 TO weekdayfl;
    
    #PRAGMA enable_profiling='json';
    #PRAGMA enable_profiling='query_tree';
    #PRAGMA enable_profiling='query_tree_optimizer';
    PRAGMA enable_profiling='json';
    PRAGMA profiling_mode='detailed';
    PRAGMA custom_profiling_settings='{"CPU_TIME": "true", "EXTRA_INFO": "true", "OPERATOR_CARDINALITY": "true", "OPERATOR_TIMING": "true", "BLOCKED_THREAD_TIME": "true", "LATENCY": "true", "OPERATOR_ROWS_SCANNED": "true", "RESULT_SET_SIZE": "true", "ROWS_RETURNED": "true"}';

    -- Queries (each run 5 times within the same instance)
    
    $(for i in {1..5}; do printf "PRAGMA profiling_output = './${OUTPUT_DIR}/Query_2.2_run%02d.json'; select sum(lineorder.revenue), date.year, part.brand1 from lineorder, date, part, supplier where lineorder.orderdate = date.datekey and lineorder.partkey = part.partkey and lineorder.suppkey = supplier.suppkey and part.brand1 between 'MFGR#2221' and 'MFGR#2228' and supplier.region = 'ASIA' group by date.year, part.brand1 order by date.year, part.brand1;\n" $i; done)
EOF

../duckdb <<EOF
    -- Setup commands (executed once)
    CREATE TABLE date AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/date.tbl');
    CREATE TABLE customer AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/customer.tbl');
    CREATE TABLE lineorder AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/lineorder.tbl');
    CREATE TABLE part AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/part.tbl');
    CREATE TABLE supplier AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/supplier.tbl');
    
    ALTER TABLE customer RENAME column0 TO custkey; ALTER TABLE customer RENAME column1 TO name; ALTER TABLE customer RENAME column2 TO address; ALTER TABLE customer RENAME column3 TO city; ALTER TABLE customer RENAME column4 TO nation; ALTER TABLE customer RENAME column5 TO region; ALTER TABLE customer RENAME column6 TO phone; ALTER TABLE customer RENAME column7 TO mktsegment;
    ALTER TABLE lineorder RENAME column00 TO orderkey; ALTER TABLE lineorder RENAME column01 TO linenumber; ALTER TABLE lineorder RENAME column02 TO custkey; ALTER TABLE lineorder RENAME column03 TO partkey; ALTER TABLE lineorder RENAME column04 TO suppkey; ALTER TABLE lineorder RENAME column05 TO orderdate; ALTER TABLE lineorder RENAME column06 TO orderpriority; ALTER TABLE lineorder RENAME column07 TO shippriority; ALTER TABLE lineorder RENAME column08 TO quantity; ALTER TABLE lineorder RENAME column09 TO extendedprice; ALTER TABLE lineorder RENAME column10 TO ordtotalprice; ALTER TABLE lineorder RENAME column11 TO discount; ALTER TABLE lineorder RENAME column12 TO revenue; ALTER TABLE lineorder RENAME column13 TO supplycost; ALTER TABLE lineorder RENAME column14 TO tax; ALTER TABLE lineorder RENAME column15 TO commitdate; ALTER TABLE lineorder RENAME column16 TO shipmode;
    ALTER TABLE part RENAME column0 TO partkey; ALTER TABLE part RENAME column1 TO name; ALTER TABLE part RENAME column2 TO mfgr; ALTER TABLE part RENAME column3 TO category; ALTER TABLE part RENAME column4 TO brand1; ALTER TABLE part RENAME column5 TO color; ALTER TABLE part RENAME column6 TO type; ALTER TABLE part RENAME column7 TO size; ALTER TABLE part RENAME column8 TO container;
    ALTER TABLE supplier RENAME column0 TO suppkey; ALTER TABLE supplier RENAME column1 TO name; ALTER TABLE supplier RENAME column2 TO address; ALTER TABLE supplier RENAME column3 TO city; ALTER TABLE supplier RENAME column4 TO nation; ALTER TABLE supplier RENAME column5 TO region; ALTER TABLE supplier RENAME column6 TO phone;
    ALTER TABLE date RENAME column00 TO datekey; ALTER TABLE date RENAME column01 TO date; ALTER TABLE date RENAME column02 TO dayofweek; ALTER TABLE date RENAME column03 TO month; ALTER TABLE date RENAME column04 TO year; ALTER TABLE date RENAME column05 TO yearmonthnum; ALTER TABLE date RENAME column06 TO yearmonth; ALTER TABLE date RENAME column07 TO daynuminweek; ALTER TABLE date RENAME column08 TO daynuminmonth; ALTER TABLE date RENAME column09 TO daynuminyear; ALTER TABLE date RENAME column10 TO monthnuminyear; ALTER TABLE date RENAME column11 TO weeknuminyear; ALTER TABLE date RENAME column12 TO sellingseason; ALTER TABLE date RENAME column13 TO lastdayinweekfl; ALTER TABLE date RENAME column14 TO lastdayinmonthfl; ALTER TABLE date RENAME column15 TO holidayfl; ALTER TABLE date RENAME column16 TO weekdayfl;
    
    #PRAGMA enable_profiling='json';
    #PRAGMA enable_profiling='query_tree';
    #PRAGMA enable_profiling='query_tree_optimizer';
    PRAGMA enable_profiling='json';
    PRAGMA profiling_mode='detailed';
    PRAGMA custom_profiling_settings='{"CPU_TIME": "true", "EXTRA_INFO": "true", "OPERATOR_CARDINALITY": "true", "OPERATOR_TIMING": "true", "BLOCKED_THREAD_TIME": "true", "LATENCY": "true", "OPERATOR_ROWS_SCANNED": "true", "RESULT_SET_SIZE": "true", "ROWS_RETURNED": "true"}';

    -- Queries (each run 5 times within the same instance)
    $(for i in {1..5}; do printf "PRAGMA profiling_output = './${OUTPUT_DIR}/Query_2.3_run%02d.json'; select sum(lineorder.revenue), date.year, part.brand1 from lineorder, date, part, supplier where lineorder.orderdate = date.datekey and lineorder.partkey = part.partkey and lineorder.suppkey = supplier.suppkey and part.brand1 = 'MFGR#2221' and supplier.region = 'EUROPE' group by date.year, part.brand1 order by date.year, part.brand1;\n" $i; done)
EOF

../duckdb <<EOF
    -- Setup commands (executed once)
    CREATE TABLE date AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/date.tbl');
    CREATE TABLE customer AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/customer.tbl');
    CREATE TABLE lineorder AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/lineorder.tbl');
    CREATE TABLE part AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/part.tbl');
    CREATE TABLE supplier AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/supplier.tbl');
    
    ALTER TABLE customer RENAME column0 TO custkey; ALTER TABLE customer RENAME column1 TO name; ALTER TABLE customer RENAME column2 TO address; ALTER TABLE customer RENAME column3 TO city; ALTER TABLE customer RENAME column4 TO nation; ALTER TABLE customer RENAME column5 TO region; ALTER TABLE customer RENAME column6 TO phone; ALTER TABLE customer RENAME column7 TO mktsegment;
    ALTER TABLE lineorder RENAME column00 TO orderkey; ALTER TABLE lineorder RENAME column01 TO linenumber; ALTER TABLE lineorder RENAME column02 TO custkey; ALTER TABLE lineorder RENAME column03 TO partkey; ALTER TABLE lineorder RENAME column04 TO suppkey; ALTER TABLE lineorder RENAME column05 TO orderdate; ALTER TABLE lineorder RENAME column06 TO orderpriority; ALTER TABLE lineorder RENAME column07 TO shippriority; ALTER TABLE lineorder RENAME column08 TO quantity; ALTER TABLE lineorder RENAME column09 TO extendedprice; ALTER TABLE lineorder RENAME column10 TO ordtotalprice; ALTER TABLE lineorder RENAME column11 TO discount; ALTER TABLE lineorder RENAME column12 TO revenue; ALTER TABLE lineorder RENAME column13 TO supplycost; ALTER TABLE lineorder RENAME column14 TO tax; ALTER TABLE lineorder RENAME column15 TO commitdate; ALTER TABLE lineorder RENAME column16 TO shipmode;
    ALTER TABLE part RENAME column0 TO partkey; ALTER TABLE part RENAME column1 TO name; ALTER TABLE part RENAME column2 TO mfgr; ALTER TABLE part RENAME column3 TO category; ALTER TABLE part RENAME column4 TO brand1; ALTER TABLE part RENAME column5 TO color; ALTER TABLE part RENAME column6 TO type; ALTER TABLE part RENAME column7 TO size; ALTER TABLE part RENAME column8 TO container;
    ALTER TABLE supplier RENAME column0 TO suppkey; ALTER TABLE supplier RENAME column1 TO name; ALTER TABLE supplier RENAME column2 TO address; ALTER TABLE supplier RENAME column3 TO city; ALTER TABLE supplier RENAME column4 TO nation; ALTER TABLE supplier RENAME column5 TO region; ALTER TABLE supplier RENAME column6 TO phone;
    ALTER TABLE date RENAME column00 TO datekey; ALTER TABLE date RENAME column01 TO date; ALTER TABLE date RENAME column02 TO dayofweek; ALTER TABLE date RENAME column03 TO month; ALTER TABLE date RENAME column04 TO year; ALTER TABLE date RENAME column05 TO yearmonthnum; ALTER TABLE date RENAME column06 TO yearmonth; ALTER TABLE date RENAME column07 TO daynuminweek; ALTER TABLE date RENAME column08 TO daynuminmonth; ALTER TABLE date RENAME column09 TO daynuminyear; ALTER TABLE date RENAME column10 TO monthnuminyear; ALTER TABLE date RENAME column11 TO weeknuminyear; ALTER TABLE date RENAME column12 TO sellingseason; ALTER TABLE date RENAME column13 TO lastdayinweekfl; ALTER TABLE date RENAME column14 TO lastdayinmonthfl; ALTER TABLE date RENAME column15 TO holidayfl; ALTER TABLE date RENAME column16 TO weekdayfl;
    
    #PRAGMA enable_profiling='json';
    #PRAGMA enable_profiling='query_tree';
    #PRAGMA enable_profiling='query_tree_optimizer';
    PRAGMA enable_profiling='json';
    PRAGMA profiling_mode='detailed';
    PRAGMA custom_profiling_settings='{"CPU_TIME": "true", "EXTRA_INFO": "true", "OPERATOR_CARDINALITY": "true", "OPERATOR_TIMING": "true", "BLOCKED_THREAD_TIME": "true", "LATENCY": "true", "OPERATOR_ROWS_SCANNED": "true", "RESULT_SET_SIZE": "true", "ROWS_RETURNED": "true"}';

    -- Queries (each run 5 times within the same instance)
    $(for i in {1..5}; do printf "PRAGMA profiling_output = './${OUTPUT_DIR}/Query_3.1_run%02d.json'; select customer.nation, supplier.nation, date.year, sum(lineorder.revenue) as revenue from customer, lineorder, supplier, date where lineorder.custkey = customer.custkey and lineorder.suppkey = supplier.suppkey and lineorder.orderdate = date.datekey and customer.region = 'ASIA' and supplier.region = 'ASIA' and date.year >= 1992 and date.year <= 1997 group by customer.nation, supplier.nation, date.year order by date.year asc, revenue desc;\n" $i; done)
EOF

../duckdb <<EOF
    -- Setup commands (executed once)
    CREATE TABLE date AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/date.tbl');
    CREATE TABLE customer AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/customer.tbl');
    CREATE TABLE lineorder AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/lineorder.tbl');
    CREATE TABLE part AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/part.tbl');
    CREATE TABLE supplier AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/supplier.tbl');
    
    ALTER TABLE customer RENAME column0 TO custkey; ALTER TABLE customer RENAME column1 TO name; ALTER TABLE customer RENAME column2 TO address; ALTER TABLE customer RENAME column3 TO city; ALTER TABLE customer RENAME column4 TO nation; ALTER TABLE customer RENAME column5 TO region; ALTER TABLE customer RENAME column6 TO phone; ALTER TABLE customer RENAME column7 TO mktsegment;
    ALTER TABLE lineorder RENAME column00 TO orderkey; ALTER TABLE lineorder RENAME column01 TO linenumber; ALTER TABLE lineorder RENAME column02 TO custkey; ALTER TABLE lineorder RENAME column03 TO partkey; ALTER TABLE lineorder RENAME column04 TO suppkey; ALTER TABLE lineorder RENAME column05 TO orderdate; ALTER TABLE lineorder RENAME column06 TO orderpriority; ALTER TABLE lineorder RENAME column07 TO shippriority; ALTER TABLE lineorder RENAME column08 TO quantity; ALTER TABLE lineorder RENAME column09 TO extendedprice; ALTER TABLE lineorder RENAME column10 TO ordtotalprice; ALTER TABLE lineorder RENAME column11 TO discount; ALTER TABLE lineorder RENAME column12 TO revenue; ALTER TABLE lineorder RENAME column13 TO supplycost; ALTER TABLE lineorder RENAME column14 TO tax; ALTER TABLE lineorder RENAME column15 TO commitdate; ALTER TABLE lineorder RENAME column16 TO shipmode;
    ALTER TABLE part RENAME column0 TO partkey; ALTER TABLE part RENAME column1 TO name; ALTER TABLE part RENAME column2 TO mfgr; ALTER TABLE part RENAME column3 TO category; ALTER TABLE part RENAME column4 TO brand1; ALTER TABLE part RENAME column5 TO color; ALTER TABLE part RENAME column6 TO type; ALTER TABLE part RENAME column7 TO size; ALTER TABLE part RENAME column8 TO container;
    ALTER TABLE supplier RENAME column0 TO suppkey; ALTER TABLE supplier RENAME column1 TO name; ALTER TABLE supplier RENAME column2 TO address; ALTER TABLE supplier RENAME column3 TO city; ALTER TABLE supplier RENAME column4 TO nation; ALTER TABLE supplier RENAME column5 TO region; ALTER TABLE supplier RENAME column6 TO phone;
    ALTER TABLE date RENAME column00 TO datekey; ALTER TABLE date RENAME column01 TO date; ALTER TABLE date RENAME column02 TO dayofweek; ALTER TABLE date RENAME column03 TO month; ALTER TABLE date RENAME column04 TO year; ALTER TABLE date RENAME column05 TO yearmonthnum; ALTER TABLE date RENAME column06 TO yearmonth; ALTER TABLE date RENAME column07 TO daynuminweek; ALTER TABLE date RENAME column08 TO daynuminmonth; ALTER TABLE date RENAME column09 TO daynuminyear; ALTER TABLE date RENAME column10 TO monthnuminyear; ALTER TABLE date RENAME column11 TO weeknuminyear; ALTER TABLE date RENAME column12 TO sellingseason; ALTER TABLE date RENAME column13 TO lastdayinweekfl; ALTER TABLE date RENAME column14 TO lastdayinmonthfl; ALTER TABLE date RENAME column15 TO holidayfl; ALTER TABLE date RENAME column16 TO weekdayfl;
    
    #PRAGMA enable_profiling='json';
    #PRAGMA enable_profiling='query_tree';
    #PRAGMA enable_profiling='query_tree_optimizer';
    PRAGMA enable_profiling='json';
    PRAGMA profiling_mode='detailed';
    PRAGMA custom_profiling_settings='{"CPU_TIME": "true", "EXTRA_INFO": "true", "OPERATOR_CARDINALITY": "true", "OPERATOR_TIMING": "true", "BLOCKED_THREAD_TIME": "true", "LATENCY": "true", "OPERATOR_ROWS_SCANNED": "true", "RESULT_SET_SIZE": "true", "ROWS_RETURNED": "true"}';

    -- Queries (each run 5 times within the same instance)
    $(for i in {1..5}; do printf "PRAGMA profiling_output = './${OUTPUT_DIR}/Query_3.2_run%02d.json'; select customer.city, supplier.city, date.year, sum(lineorder.revenue) as revenue from customer, lineorder, supplier, date where lineorder.custkey = customer.custkey and lineorder.suppkey = supplier.suppkey and lineorder.orderdate = date.datekey and customer.nation = 'UNITED STATES' and supplier.nation = 'UNITED STATES' and date.year >= 1992 and date.year <= 1997 group by customer.city, supplier.city, date.year order by date.year asc, revenue desc;\n" $i; done)
EOF

../duckdb <<EOF
    -- Setup commands (executed once)
    CREATE TABLE date AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/date.tbl');
    CREATE TABLE customer AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/customer.tbl');
    CREATE TABLE lineorder AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/lineorder.tbl');
    CREATE TABLE part AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/part.tbl');
    CREATE TABLE supplier AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/supplier.tbl');
    
    ALTER TABLE customer RENAME column0 TO custkey; ALTER TABLE customer RENAME column1 TO name; ALTER TABLE customer RENAME column2 TO address; ALTER TABLE customer RENAME column3 TO city; ALTER TABLE customer RENAME column4 TO nation; ALTER TABLE customer RENAME column5 TO region; ALTER TABLE customer RENAME column6 TO phone; ALTER TABLE customer RENAME column7 TO mktsegment;
    ALTER TABLE lineorder RENAME column00 TO orderkey; ALTER TABLE lineorder RENAME column01 TO linenumber; ALTER TABLE lineorder RENAME column02 TO custkey; ALTER TABLE lineorder RENAME column03 TO partkey; ALTER TABLE lineorder RENAME column04 TO suppkey; ALTER TABLE lineorder RENAME column05 TO orderdate; ALTER TABLE lineorder RENAME column06 TO orderpriority; ALTER TABLE lineorder RENAME column07 TO shippriority; ALTER TABLE lineorder RENAME column08 TO quantity; ALTER TABLE lineorder RENAME column09 TO extendedprice; ALTER TABLE lineorder RENAME column10 TO ordtotalprice; ALTER TABLE lineorder RENAME column11 TO discount; ALTER TABLE lineorder RENAME column12 TO revenue; ALTER TABLE lineorder RENAME column13 TO supplycost; ALTER TABLE lineorder RENAME column14 TO tax; ALTER TABLE lineorder RENAME column15 TO commitdate; ALTER TABLE lineorder RENAME column16 TO shipmode;
    ALTER TABLE part RENAME column0 TO partkey; ALTER TABLE part RENAME column1 TO name; ALTER TABLE part RENAME column2 TO mfgr; ALTER TABLE part RENAME column3 TO category; ALTER TABLE part RENAME column4 TO brand1; ALTER TABLE part RENAME column5 TO color; ALTER TABLE part RENAME column6 TO type; ALTER TABLE part RENAME column7 TO size; ALTER TABLE part RENAME column8 TO container;
    ALTER TABLE supplier RENAME column0 TO suppkey; ALTER TABLE supplier RENAME column1 TO name; ALTER TABLE supplier RENAME column2 TO address; ALTER TABLE supplier RENAME column3 TO city; ALTER TABLE supplier RENAME column4 TO nation; ALTER TABLE supplier RENAME column5 TO region; ALTER TABLE supplier RENAME column6 TO phone;
    ALTER TABLE date RENAME column00 TO datekey; ALTER TABLE date RENAME column01 TO date; ALTER TABLE date RENAME column02 TO dayofweek; ALTER TABLE date RENAME column03 TO month; ALTER TABLE date RENAME column04 TO year; ALTER TABLE date RENAME column05 TO yearmonthnum; ALTER TABLE date RENAME column06 TO yearmonth; ALTER TABLE date RENAME column07 TO daynuminweek; ALTER TABLE date RENAME column08 TO daynuminmonth; ALTER TABLE date RENAME column09 TO daynuminyear; ALTER TABLE date RENAME column10 TO monthnuminyear; ALTER TABLE date RENAME column11 TO weeknuminyear; ALTER TABLE date RENAME column12 TO sellingseason; ALTER TABLE date RENAME column13 TO lastdayinweekfl; ALTER TABLE date RENAME column14 TO lastdayinmonthfl; ALTER TABLE date RENAME column15 TO holidayfl; ALTER TABLE date RENAME column16 TO weekdayfl;
    
    #PRAGMA enable_profiling='json';
    #PRAGMA enable_profiling='query_tree';
    #PRAGMA enable_profiling='query_tree_optimizer';
    PRAGMA enable_profiling='json';
    PRAGMA profiling_mode='detailed';
    PRAGMA custom_profiling_settings='{"CPU_TIME": "true", "EXTRA_INFO": "true", "OPERATOR_CARDINALITY": "true", "OPERATOR_TIMING": "true", "BLOCKED_THREAD_TIME": "true", "LATENCY": "true", "OPERATOR_ROWS_SCANNED": "true", "RESULT_SET_SIZE": "true", "ROWS_RETURNED": "true"}';

    -- Queries (each run 5 times within the same instance)
    $(for i in {1..5}; do printf "PRAGMA profiling_output = './${OUTPUT_DIR}/Query_3.3_run%02d.json'; select customer.city, supplier.city, date.year, sum(lineorder.revenue) as revenue from customer, lineorder, supplier, date where lineorder.custkey = customer.custkey and lineorder.suppkey = supplier.suppkey and lineorder.orderdate = date.datekey and (customer.city='UNITED KI1' or customer.city='UNITED KI5') and (supplier.city='UNITED KI1' or supplier.city='UNITED KI5') and date.year >= 1992 and date.year <= 1997 group by customer.city, supplier.city, date.year order by date.year asc, revenue desc;\n" $i; done)
EOF

../duckdb <<EOF
    -- Setup commands (executed once)
    CREATE TABLE date AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/date.tbl');
    CREATE TABLE customer AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/customer.tbl');
    CREATE TABLE lineorder AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/lineorder.tbl');
    CREATE TABLE part AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/part.tbl');
    CREATE TABLE supplier AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/supplier.tbl');
    
    ALTER TABLE customer RENAME column0 TO custkey; ALTER TABLE customer RENAME column1 TO name; ALTER TABLE customer RENAME column2 TO address; ALTER TABLE customer RENAME column3 TO city; ALTER TABLE customer RENAME column4 TO nation; ALTER TABLE customer RENAME column5 TO region; ALTER TABLE customer RENAME column6 TO phone; ALTER TABLE customer RENAME column7 TO mktsegment;
    ALTER TABLE lineorder RENAME column00 TO orderkey; ALTER TABLE lineorder RENAME column01 TO linenumber; ALTER TABLE lineorder RENAME column02 TO custkey; ALTER TABLE lineorder RENAME column03 TO partkey; ALTER TABLE lineorder RENAME column04 TO suppkey; ALTER TABLE lineorder RENAME column05 TO orderdate; ALTER TABLE lineorder RENAME column06 TO orderpriority; ALTER TABLE lineorder RENAME column07 TO shippriority; ALTER TABLE lineorder RENAME column08 TO quantity; ALTER TABLE lineorder RENAME column09 TO extendedprice; ALTER TABLE lineorder RENAME column10 TO ordtotalprice; ALTER TABLE lineorder RENAME column11 TO discount; ALTER TABLE lineorder RENAME column12 TO revenue; ALTER TABLE lineorder RENAME column13 TO supplycost; ALTER TABLE lineorder RENAME column14 TO tax; ALTER TABLE lineorder RENAME column15 TO commitdate; ALTER TABLE lineorder RENAME column16 TO shipmode;
    ALTER TABLE part RENAME column0 TO partkey; ALTER TABLE part RENAME column1 TO name; ALTER TABLE part RENAME column2 TO mfgr; ALTER TABLE part RENAME column3 TO category; ALTER TABLE part RENAME column4 TO brand1; ALTER TABLE part RENAME column5 TO color; ALTER TABLE part RENAME column6 TO type; ALTER TABLE part RENAME column7 TO size; ALTER TABLE part RENAME column8 TO container;
    ALTER TABLE supplier RENAME column0 TO suppkey; ALTER TABLE supplier RENAME column1 TO name; ALTER TABLE supplier RENAME column2 TO address; ALTER TABLE supplier RENAME column3 TO city; ALTER TABLE supplier RENAME column4 TO nation; ALTER TABLE supplier RENAME column5 TO region; ALTER TABLE supplier RENAME column6 TO phone;
    ALTER TABLE date RENAME column00 TO datekey; ALTER TABLE date RENAME column01 TO date; ALTER TABLE date RENAME column02 TO dayofweek; ALTER TABLE date RENAME column03 TO month; ALTER TABLE date RENAME column04 TO year; ALTER TABLE date RENAME column05 TO yearmonthnum; ALTER TABLE date RENAME column06 TO yearmonth; ALTER TABLE date RENAME column07 TO daynuminweek; ALTER TABLE date RENAME column08 TO daynuminmonth; ALTER TABLE date RENAME column09 TO daynuminyear; ALTER TABLE date RENAME column10 TO monthnuminyear; ALTER TABLE date RENAME column11 TO weeknuminyear; ALTER TABLE date RENAME column12 TO sellingseason; ALTER TABLE date RENAME column13 TO lastdayinweekfl; ALTER TABLE date RENAME column14 TO lastdayinmonthfl; ALTER TABLE date RENAME column15 TO holidayfl; ALTER TABLE date RENAME column16 TO weekdayfl;
    
    #PRAGMA enable_profiling='json';
    #PRAGMA enable_profiling='query_tree';
    #PRAGMA enable_profiling='query_tree_optimizer';
    PRAGMA enable_profiling='json';
    PRAGMA profiling_mode='detailed';
    PRAGMA custom_profiling_settings='{"CPU_TIME": "true", "EXTRA_INFO": "true", "OPERATOR_CARDINALITY": "true", "OPERATOR_TIMING": "true", "BLOCKED_THREAD_TIME": "true", "LATENCY": "true", "OPERATOR_ROWS_SCANNED": "true", "RESULT_SET_SIZE": "true", "ROWS_RETURNED": "true"}';

    -- Queries (each run 5 times within the same instance)
    $(for i in {1..5}; do printf "PRAGMA profiling_output = './${OUTPUT_DIR}/Query_3.4_run%02d.json'; select customer.city, supplier.city, date.year, sum(lineorder.revenue) as revenue from customer, lineorder, supplier, date where lineorder.custkey = customer.custkey and lineorder.suppkey = supplier.suppkey and lineorder.orderdate = date.datekey and (customer.city='UNITED KI1' or customer.city='UNITED KI5') and (supplier.city='UNITED KI1' or supplier.city='UNITED KI5') and date.yearmonth = 'Dec1997' group by customer.city, supplier.city, date.year order by date.year asc, revenue desc;\n" $i; done)
EOF

../duckdb <<EOF
    -- Setup commands (executed once)
    CREATE TABLE date AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/date.tbl');
    CREATE TABLE customer AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/customer.tbl');
    CREATE TABLE lineorder AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/lineorder.tbl');
    CREATE TABLE part AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/part.tbl');
    CREATE TABLE supplier AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/supplier.tbl');
    
    ALTER TABLE customer RENAME column0 TO custkey; ALTER TABLE customer RENAME column1 TO name; ALTER TABLE customer RENAME column2 TO address; ALTER TABLE customer RENAME column3 TO city; ALTER TABLE customer RENAME column4 TO nation; ALTER TABLE customer RENAME column5 TO region; ALTER TABLE customer RENAME column6 TO phone; ALTER TABLE customer RENAME column7 TO mktsegment;
    ALTER TABLE lineorder RENAME column00 TO orderkey; ALTER TABLE lineorder RENAME column01 TO linenumber; ALTER TABLE lineorder RENAME column02 TO custkey; ALTER TABLE lineorder RENAME column03 TO partkey; ALTER TABLE lineorder RENAME column04 TO suppkey; ALTER TABLE lineorder RENAME column05 TO orderdate; ALTER TABLE lineorder RENAME column06 TO orderpriority; ALTER TABLE lineorder RENAME column07 TO shippriority; ALTER TABLE lineorder RENAME column08 TO quantity; ALTER TABLE lineorder RENAME column09 TO extendedprice; ALTER TABLE lineorder RENAME column10 TO ordtotalprice; ALTER TABLE lineorder RENAME column11 TO discount; ALTER TABLE lineorder RENAME column12 TO revenue; ALTER TABLE lineorder RENAME column13 TO supplycost; ALTER TABLE lineorder RENAME column14 TO tax; ALTER TABLE lineorder RENAME column15 TO commitdate; ALTER TABLE lineorder RENAME column16 TO shipmode;
    ALTER TABLE part RENAME column0 TO partkey; ALTER TABLE part RENAME column1 TO name; ALTER TABLE part RENAME column2 TO mfgr; ALTER TABLE part RENAME column3 TO category; ALTER TABLE part RENAME column4 TO brand1; ALTER TABLE part RENAME column5 TO color; ALTER TABLE part RENAME column6 TO type; ALTER TABLE part RENAME column7 TO size; ALTER TABLE part RENAME column8 TO container;
    ALTER TABLE supplier RENAME column0 TO suppkey; ALTER TABLE supplier RENAME column1 TO name; ALTER TABLE supplier RENAME column2 TO address; ALTER TABLE supplier RENAME column3 TO city; ALTER TABLE supplier RENAME column4 TO nation; ALTER TABLE supplier RENAME column5 TO region; ALTER TABLE supplier RENAME column6 TO phone;
    ALTER TABLE date RENAME column00 TO datekey; ALTER TABLE date RENAME column01 TO date; ALTER TABLE date RENAME column02 TO dayofweek; ALTER TABLE date RENAME column03 TO month; ALTER TABLE date RENAME column04 TO year; ALTER TABLE date RENAME column05 TO yearmonthnum; ALTER TABLE date RENAME column06 TO yearmonth; ALTER TABLE date RENAME column07 TO daynuminweek; ALTER TABLE date RENAME column08 TO daynuminmonth; ALTER TABLE date RENAME column09 TO daynuminyear; ALTER TABLE date RENAME column10 TO monthnuminyear; ALTER TABLE date RENAME column11 TO weeknuminyear; ALTER TABLE date RENAME column12 TO sellingseason; ALTER TABLE date RENAME column13 TO lastdayinweekfl; ALTER TABLE date RENAME column14 TO lastdayinmonthfl; ALTER TABLE date RENAME column15 TO holidayfl; ALTER TABLE date RENAME column16 TO weekdayfl;
    
    #PRAGMA enable_profiling='json';
    #PRAGMA enable_profiling='query_tree';
    #PRAGMA enable_profiling='query_tree_optimizer';
    PRAGMA enable_profiling='json';
    PRAGMA profiling_mode='detailed';
    PRAGMA custom_profiling_settings='{"CPU_TIME": "true", "EXTRA_INFO": "true", "OPERATOR_CARDINALITY": "true", "OPERATOR_TIMING": "true", "BLOCKED_THREAD_TIME": "true", "LATENCY": "true", "OPERATOR_ROWS_SCANNED": "true", "RESULT_SET_SIZE": "true", "ROWS_RETURNED": "true"}';

    -- Queries (each run 5 times within the same instance)
    $(for i in {1..5}; do printf "PRAGMA profiling_output = './${OUTPUT_DIR}/Query_4.1_run%02d.json'; select date.year, customer.nation, sum(lineorder.revenue - lineorder.supplycost) as profit from date, customer, supplier, part, lineorder where lineorder.custkey = customer.custkey and lineorder.suppkey = supplier.suppkey and lineorder.partkey = part.partkey and lineorder.orderdate = date.datekey and customer.region = 'AMERICA' and supplier.region = 'AMERICA' and (part.mfgr = 'MFGR#1' or part.mfgr = 'MFGR#2') group by date.year, customer.nation order by date.year, customer.nation;\n" $i; done)
EOF

../duckdb <<EOF
    -- Setup commands (executed once)
    CREATE TABLE date AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/date.tbl');
    CREATE TABLE customer AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/customer.tbl');
    CREATE TABLE lineorder AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/lineorder.tbl');
    CREATE TABLE part AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/part.tbl');
    CREATE TABLE supplier AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/supplier.tbl');
    
    ALTER TABLE customer RENAME column0 TO custkey; ALTER TABLE customer RENAME column1 TO name; ALTER TABLE customer RENAME column2 TO address; ALTER TABLE customer RENAME column3 TO city; ALTER TABLE customer RENAME column4 TO nation; ALTER TABLE customer RENAME column5 TO region; ALTER TABLE customer RENAME column6 TO phone; ALTER TABLE customer RENAME column7 TO mktsegment;
    ALTER TABLE lineorder RENAME column00 TO orderkey; ALTER TABLE lineorder RENAME column01 TO linenumber; ALTER TABLE lineorder RENAME column02 TO custkey; ALTER TABLE lineorder RENAME column03 TO partkey; ALTER TABLE lineorder RENAME column04 TO suppkey; ALTER TABLE lineorder RENAME column05 TO orderdate; ALTER TABLE lineorder RENAME column06 TO orderpriority; ALTER TABLE lineorder RENAME column07 TO shippriority; ALTER TABLE lineorder RENAME column08 TO quantity; ALTER TABLE lineorder RENAME column09 TO extendedprice; ALTER TABLE lineorder RENAME column10 TO ordtotalprice; ALTER TABLE lineorder RENAME column11 TO discount; ALTER TABLE lineorder RENAME column12 TO revenue; ALTER TABLE lineorder RENAME column13 TO supplycost; ALTER TABLE lineorder RENAME column14 TO tax; ALTER TABLE lineorder RENAME column15 TO commitdate; ALTER TABLE lineorder RENAME column16 TO shipmode;
    ALTER TABLE part RENAME column0 TO partkey; ALTER TABLE part RENAME column1 TO name; ALTER TABLE part RENAME column2 TO mfgr; ALTER TABLE part RENAME column3 TO category; ALTER TABLE part RENAME column4 TO brand1; ALTER TABLE part RENAME column5 TO color; ALTER TABLE part RENAME column6 TO type; ALTER TABLE part RENAME column7 TO size; ALTER TABLE part RENAME column8 TO container;
    ALTER TABLE supplier RENAME column0 TO suppkey; ALTER TABLE supplier RENAME column1 TO name; ALTER TABLE supplier RENAME column2 TO address; ALTER TABLE supplier RENAME column3 TO city; ALTER TABLE supplier RENAME column4 TO nation; ALTER TABLE supplier RENAME column5 TO region; ALTER TABLE supplier RENAME column6 TO phone;
    ALTER TABLE date RENAME column00 TO datekey; ALTER TABLE date RENAME column01 TO date; ALTER TABLE date RENAME column02 TO dayofweek; ALTER TABLE date RENAME column03 TO month; ALTER TABLE date RENAME column04 TO year; ALTER TABLE date RENAME column05 TO yearmonthnum; ALTER TABLE date RENAME column06 TO yearmonth; ALTER TABLE date RENAME column07 TO daynuminweek; ALTER TABLE date RENAME column08 TO daynuminmonth; ALTER TABLE date RENAME column09 TO daynuminyear; ALTER TABLE date RENAME column10 TO monthnuminyear; ALTER TABLE date RENAME column11 TO weeknuminyear; ALTER TABLE date RENAME column12 TO sellingseason; ALTER TABLE date RENAME column13 TO lastdayinweekfl; ALTER TABLE date RENAME column14 TO lastdayinmonthfl; ALTER TABLE date RENAME column15 TO holidayfl; ALTER TABLE date RENAME column16 TO weekdayfl;
    
    #PRAGMA enable_profiling='json';
    #PRAGMA enable_profiling='query_tree';
    #PRAGMA enable_profiling='query_tree_optimizer';
    PRAGMA enable_profiling='json';
    PRAGMA profiling_mode='detailed';
    PRAGMA custom_profiling_settings='{"CPU_TIME": "true", "EXTRA_INFO": "true", "OPERATOR_CARDINALITY": "true", "OPERATOR_TIMING": "true", "BLOCKED_THREAD_TIME": "true", "LATENCY": "true", "OPERATOR_ROWS_SCANNED": "true", "RESULT_SET_SIZE": "true", "ROWS_RETURNED": "true"}';

    -- Queries (each run 5 times within the same instance)
    $(for i in {1..5}; do printf "PRAGMA profiling_output = './${OUTPUT_DIR}/Query_4.2_run%02d.json'; select date.year, supplier.nation, part.category, sum(lineorder.revenue - lineorder.supplycost) as profit from date, customer, supplier, part, lineorder where lineorder.custkey = customer.custkey and lineorder.suppkey = supplier.suppkey and lineorder.partkey = part.partkey and lineorder.orderdate = date.datekey and customer.region = 'AMERICA' and supplier.region = 'AMERICA' and (date.year = 1997 or date.year = 1998) and (part.mfgr = 'MFGR#1' or part.mfgr = 'MFGR#2') group by date.year, supplier.nation, part.category order by date.year, supplier.nation, part.category;\n" $i; done)
EOF
../duckdb <<EOF
    -- Setup commands (executed once)
    CREATE TABLE date AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/date.tbl');
    CREATE TABLE customer AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/customer.tbl');
    CREATE TABLE lineorder AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/lineorder.tbl');
    CREATE TABLE part AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/part.tbl');
    CREATE TABLE supplier AS SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/supplier.tbl');
    
    ALTER TABLE customer RENAME column0 TO custkey; ALTER TABLE customer RENAME column1 TO name; ALTER TABLE customer RENAME column2 TO address; ALTER TABLE customer RENAME column3 TO city; ALTER TABLE customer RENAME column4 TO nation; ALTER TABLE customer RENAME column5 TO region; ALTER TABLE customer RENAME column6 TO phone; ALTER TABLE customer RENAME column7 TO mktsegment;
    ALTER TABLE lineorder RENAME column00 TO orderkey; ALTER TABLE lineorder RENAME column01 TO linenumber; ALTER TABLE lineorder RENAME column02 TO custkey; ALTER TABLE lineorder RENAME column03 TO partkey; ALTER TABLE lineorder RENAME column04 TO suppkey; ALTER TABLE lineorder RENAME column05 TO orderdate; ALTER TABLE lineorder RENAME column06 TO orderpriority; ALTER TABLE lineorder RENAME column07 TO shippriority; ALTER TABLE lineorder RENAME column08 TO quantity; ALTER TABLE lineorder RENAME column09 TO extendedprice; ALTER TABLE lineorder RENAME column10 TO ordtotalprice; ALTER TABLE lineorder RENAME column11 TO discount; ALTER TABLE lineorder RENAME column12 TO revenue; ALTER TABLE lineorder RENAME column13 TO supplycost; ALTER TABLE lineorder RENAME column14 TO tax; ALTER TABLE lineorder RENAME column15 TO commitdate; ALTER TABLE lineorder RENAME column16 TO shipmode;
    ALTER TABLE part RENAME column0 TO partkey; ALTER TABLE part RENAME column1 TO name; ALTER TABLE part RENAME column2 TO mfgr; ALTER TABLE part RENAME column3 TO category; ALTER TABLE part RENAME column4 TO brand1; ALTER TABLE part RENAME column5 TO color; ALTER TABLE part RENAME column6 TO type; ALTER TABLE part RENAME column7 TO size; ALTER TABLE part RENAME column8 TO container;
    ALTER TABLE supplier RENAME column0 TO suppkey; ALTER TABLE supplier RENAME column1 TO name; ALTER TABLE supplier RENAME column2 TO address; ALTER TABLE supplier RENAME column3 TO city; ALTER TABLE supplier RENAME column4 TO nation; ALTER TABLE supplier RENAME column5 TO region; ALTER TABLE supplier RENAME column6 TO phone;
    ALTER TABLE date RENAME column00 TO datekey; ALTER TABLE date RENAME column01 TO date; ALTER TABLE date RENAME column02 TO dayofweek; ALTER TABLE date RENAME column03 TO month; ALTER TABLE date RENAME column04 TO year; ALTER TABLE date RENAME column05 TO yearmonthnum; ALTER TABLE date RENAME column06 TO yearmonth; ALTER TABLE date RENAME column07 TO daynuminweek; ALTER TABLE date RENAME column08 TO daynuminmonth; ALTER TABLE date RENAME column09 TO daynuminyear; ALTER TABLE date RENAME column10 TO monthnuminyear; ALTER TABLE date RENAME column11 TO weeknuminyear; ALTER TABLE date RENAME column12 TO sellingseason; ALTER TABLE date RENAME column13 TO lastdayinweekfl; ALTER TABLE date RENAME column14 TO lastdayinmonthfl; ALTER TABLE date RENAME column15 TO holidayfl; ALTER TABLE date RENAME column16 TO weekdayfl;
    
    #PRAGMA enable_profiling='json';
    #PRAGMA enable_profiling='query_tree';
    #PRAGMA enable_profiling='query_tree_optimizer';
    PRAGMA enable_profiling='json';
    PRAGMA profiling_mode='detailed';
    PRAGMA custom_profiling_settings='{"CPU_TIME": "true", "EXTRA_INFO": "true", "OPERATOR_CARDINALITY": "true", "OPERATOR_TIMING": "true", "BLOCKED_THREAD_TIME": "true", "LATENCY": "true", "OPERATOR_ROWS_SCANNED": "true", "RESULT_SET_SIZE": "true", "ROWS_RETURNED": "true"}';

    -- Queries (each run 5 times within the same instance)
    $(for i in {1..5}; do printf "PRAGMA profiling_output = './${OUTPUT_DIR}/Query_4.3_run%02d.json'; select date.year, supplier.city, part.brand1, sum(lineorder.revenue - lineorder.supplycost) as profit from date, customer, supplier, part, lineorder where lineorder.custkey = customer.custkey and lineorder.suppkey = supplier.suppkey and lineorder.partkey = part.partkey and lineorder.orderdate = date.datekey and customer.region = 'AMERICA' and supplier.nation = 'UNITED STATES' and (date.year = 1997 or date.year = 1998) and part.category = 'MFGR#14' group by date.year, supplier.city, part.brand1 order by date.year, supplier.city, part.brand1;\n" $i; done)
EOF


echo "Profiling session completed!"
echo "All output files are in ${OUTPUT_DIR}"
