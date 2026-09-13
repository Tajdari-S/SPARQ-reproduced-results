import dask_cudf
from dask.distributed import Client
from dask_cuda import LocalCUDACluster
import rmm
import time
import gc
from datetime import datetime
import dask
import cupy as cp
import os

# Data locations. Defaults are the paths the paper's measurements used. The SF100
# copy is comma-separated with quoted dates; set SF100_SEP='|' for dbgen output.
SF1_DIR = os.environ.get('SF1_DIR', '/p/pd/pim/sf1/')
SF10_DIR = os.environ.get('SF10_DIR', '/p/pd/pim/sf10/')
SF100_DIR = os.environ.get('SF100_DIR', '/p/pd/ssb-dbgen/sf100/')
SF100_SEP = os.environ.get('SF100_SEP', ',')

def initialize_dask():
    """Initialize Dask with CUDA cluster and RMM memory pool."""
    cluster = LocalCUDACluster(
        rmm_pool_size='20GiB',  # Adjust to match your GPU memory (e.g., < total GPU memory)
        protocol="tcp",
        enable_tcp_over_ucx=False,
        threads_per_worker=1,
        device_memory_limit="8GB"  # Increase to allow more partitions in memory
    )
    client = Client(cluster)
    client.run(rmm.reinitialize,
               pool_allocator=True,
               initial_pool_size='20GiB')
    print(f"Dask Cluster Initialized: {client}")
    return client

def load_table(file_path, column_names, blocksize):
    """Load table with optimized partitioning."""
    try:
        if file_path.startswith(SF100_DIR):
            df = dask_cudf.read_csv(
                file_path,
                sep=SF100_SEP,
                names=column_names,
                blocksize=blocksize,  # Smaller blocksize for sf100 (e.g., 256 MiB)
                dtype='int32'
            )
        else:
            df = dask_cudf.read_csv(
                file_path,
                sep='|',
                names=column_names,
                blocksize=blocksize,  # Larger blocksize for sf1/sf10 (e.g., 1024 MiB)
                dtype='int32'
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
    return df.persist()

def process_join(left_df, right_df, left_key, right_key, transmit_to_cpu=False, client=None):
    """Perform join on GPU, measure computation time, and optionally transmit to CPU."""
    try:
        # Persist only smaller tables to save memory
        if right_df.npartitions < 10:  # Threshold for small tables
            right_df = client.persist(right_df)
        
        # Use broadcast join for small right tables
        joined = left_df.merge(
            right_df,
            left_on=left_key,
            right_on=right_key,
            how='inner',
            broadcast=True if right_df.npartitions < 10 else False
        )
        
        # Measure GPU computation time
        cp.cuda.Device(0).synchronize()
        start_compute = time.time()
        joined = client.persist(joined)
        dask.distributed.wait(joined)  # Wait for computation to complete on GPU
        end_compute = time.time()
        compute_duration = (end_compute - start_compute) * 1e9  # ns
        
        if transmit_to_cpu:
            start_transfer = time.time()
            result = joined.compute()  # Brings result to CPU
            end_transfer = time.time()
            transfer_duration = (end_transfer - start_transfer) * 1e9  # ns
            print(f"Join computed in {compute_duration:.4f}ns (GPU time), "
                  f"transferred to CPU in {transfer_duration:.4f}ns, "
                  f"result has {len(result):,} rows")
            del result
        else:
            count = joined.shape[0].compute()  # Compute count on GPU
            print(f"Join computed in {compute_duration:.4f}ns (GPU time), "
                  f"result has {count:,} rows")
        
        del joined
        return compute_duration, transfer_duration if transmit_to_cpu else None
    except Exception as e:
        print(f"Join failed: {str(e)}")
        return None, None

def main():
    rmm.reinitialize(pool_allocator=False, managed_memory=True)
    client = initialize_dask()
    dask.config.set({
        "distributed.worker.memory.target": 0.5,  # Start spilling earlier
        "distributed.worker.memory.spill": 0.6,   # Spill when 60% full
        "distributed.worker.memory.pause": 0.7    # Pause at 70%
    })
    print(f"\nSSB Benchmark Started: {datetime.now()}", flush=True)

    scale_factors = [
        # one run type for every SF: SF100's settings, since SF100 does not fit otherwise
        ('1', SF1_DIR, False, "256 MiB"),
        ('10', SF10_DIR, False, "256 MiB"),
        ('100', SF100_DIR, False, "256 MiB")
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

    for scale, path, transmit_to_cpu, blocksize in scale_factors:
        print(f"\n{'='*40}\nProcessing SF{scale} at {datetime.now()}\n{'='*40}")
        
        tables = {}
        for table in ['lineorder', 'date', 'customer', 'supplier', 'part']:
            file = f"{path}{table}.tbl"
            tables[table] = load_table(file, schema[table], blocksize)
            if tables[table] is not None:
                tables[table] = optimize_schema(tables[table], numeric_cols.get(table, []))

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
                
            compute_duration, transfer_duration = process_join(
                tables[left_tbl],
                tables[right_tbl],
                lkey,
                rkey,
                transmit_to_cpu=transmit_to_cpu,
                client=client
            )
            
            client.run(lambda: gc.collect())
            print(f"Memory cleaned after {left_tbl}-{right_tbl} join")

        del tables
        client.run(lambda: [gc.collect(), cp.get_default_memory_pool().free_all_blocks()])
        print(f"\nCompleted SF{scale} processing at {datetime.now()}")

if __name__ == "__main__":
    main()