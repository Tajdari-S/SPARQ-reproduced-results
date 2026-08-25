import dask_cudf
from dask.distributed import Client
from dask_cuda import LocalCUDACluster
import rmm
import time
import gc
from datetime import datetime
import dask

import cupy as cp


def initialize_dask():
    """Initialize Dask with CUDA cluster and RMM memory pool."""
    cluster = LocalCUDACluster(
        rmm_pool_size='30GiB',  # Adjust based on GPU capacity
        protocol="ucx",
        enable_tcp_over_ucx=False,
         threads_per_worker=1,
         device_memory_limit="4GB"
    )
    client = Client(cluster)
    # Initialize RMM pool on all workers
    client.run(rmm.reinitialize,
               pool_allocator=True,
               initial_pool_size='30GiB')  # Match pool size with worker memory
    print(f"Dask Cluster Initialized: {client}")
    return client

def load_table(file_path, column_names):
    """Load table with optimized partitioning."""
    try:
        if file_path == '/p/pd/ssb-dbgen/sf100/':
            df = dask_cudf.read_csv(
                file_path,
                sep=',',
                names=column_names,
                blocksize="512 MiB",  # Control partition size
                dtype='int32',  # Auto-detect numeric columns
            )
            print(f"Lazily loaded {file_path} | Partitions: {df.npartitions}")
            return df
        else:
            df = dask_cudf.read_csv(
                file_path,
                sep='|',
                names=column_names,
                blocksize="512 MiB",  # Control partition size
                dtype='int32',  # Auto-detect numeric columns
            )
            print(f"Lazily loaded {file_path} | Partitions: {df.npartitions}")
            return df
    except Exception as e:
        print(f"Error loading {file_path}: {str(e)}")
        return None

def optimize_schema(df, numeric_cols):
    """Optimize data types in-place."""
    for col in numeric_cols:
        if col in df.columns:
            df[col] = df[col].astype('int32')
    return df.persist()  # Keep optimized data in memory

def process_join(left_df, right_df, left_key, right_key):
    """Perform join and measure pure computation latency using GPU timers."""
    try:
        cp.cuda.Device(0).synchronize()  # Ensure GPU is idle before timing
        start = cp.cuda.Event(); end = cp.cuda.Event()
        
        start.record()  # Start GPU timing
        joined = left_df.merge(
            right_df,
            left_on=left_key,
            right_on=right_key,
            how='inner'
        )
        #joined = joined.persist()  # Keep join in memory without fetching results
        end.record()  # End GPU timing
        
        end.synchronize()  # Ensure event timing is complete
        duration = cp.cuda.get_elapsed_time(start, end)*1000000  # ns
        
        count = joined.shape[0].compute()  # Metadata computation (not affecting join timing)
        print(f"Join completed: {count:,} rows in {duration:.4f}ns (pure GPU time)")
        
        del joined  # Cleanup memory
        return duration
    except Exception as e:
        print(f"Join failed: {str(e)}")
        return None

def main():
    rmm.reinitialize(pool_allocator=False, managed_memory=True)
    client = initialize_dask()
    dask.config.set({
    "distributed.worker.memory.target": 0.65,  # More aggressive memory management
    "distributed.worker.memory.spill": 0.6,
    "distributed.worker.memory.pause": 0.7
})
    print(f"\nSSB Benchmark Started: {datetime.now()}", flush=True)

    scale_factors = [
        
        ('1', '/p/pd/pim/sf1/'),
        ('10', '/p/pd/pim/sf10/'),
        ('100', '/p/pd/ssb-dbgen/sf100/')
    ]

    schema = {
        'lineorder': ['lo_orderkey', 'lo_linenumber', 'lo_custkey', 'lo_partkey',
                      'lo_suppkey', 'lo_orderdate', 'lo_orderpriority', 'lo_shippriority',
                      'lo_quantity', 'lo_extendedprice', 'lo_ordtotalprice', 'lo_discount',
                      'lo_revenue', 'lo_supplycost', 'lo_tax', 'lo_commitdate', 'lo_shipmode'],
        'date': ['d_datekey', 'd_date', 'd_dayofweek', 'd_month', 'd_year'],
        'customer': ['c_custkey', 'c_name', 'c_address', 'c_city'],
        'supplier': ['s_suppkey', 's_name', 's_address', 's_city'],
        'part': ['p_partkey', 'p_name', 'p_mfgr', 'p_category']
    }

    numeric_cols = {
        'lineorder': ['lo_custkey', 'lo_orderdate', 'lo_suppkey', 'lo_partkey'],
        'customer': ['c_custkey'],
        'date': ['d_datekey'],
        'supplier': ['s_suppkey'],
        'part': ['p_partkey']
    }

    for scale, path in scale_factors:
        print(f"\n{'='*40}\nProcessing SF{scale} at {datetime.now()}\n{'='*40}")
        
        # Load all tables first
        tables = {}
        for table in ['lineorder', 'date', 'customer', 'supplier', 'part']:
            file = f"{path}{table}.tbl"
            tables[table] = load_table(file, schema[table])
            if tables[table] is not None:
                tables[table] = optimize_schema(tables[table], numeric_cols.get(table, []))
        
        # Process joins
        joins = [
            ('lineorder', 'customer', 'lo_custkey', 'c_custkey'),
            ('lineorder', 'date', 'lo_orderdate', 'd_datekey'),
            ('lineorder', 'supplier', 'lo_suppkey', 's_suppkey'),
            ('lineorder', 'part', 'lo_partkey', 'p_partkey'),
            ('lineorder', 'customer', 'lo_custkey', 'c_custkey')
        ]

        for left_tbl, right_tbl, lkey, rkey in joins:
            print(f"\nJoining {left_tbl} ⋈ {right_tbl}")
            if tables.get(left_tbl) is None or tables.get(right_tbl) is None:
                continue
                
            duration = process_join(
                tables[left_tbl],
                tables[right_tbl],
                lkey,
                rkey
            )
            
            # Cleanup intermediate data
            client.run(lambda: gc.collect())
            print(f"Memory cleaned after {left_tbl}-{right_tbl} join")

        # Release all tables before next scale factor
        del tables
        client.run(lambda: [gc.collect(), cp.get_default_memory_pool().free_all_blocks()])
        print(f"\nCompleted SF{scale} processing at {datetime.now()}")

if __name__ == "__main__":
    main()