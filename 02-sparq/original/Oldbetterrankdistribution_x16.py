import math
import multiprocessing as mp
from pathlib import Path
import numpy as np
from itertools import islice

# DDR4 Configuration Parameters
MaxRowAddress = 65536
NumOfCol = 1024
NumOfBanks = 4
NumOfBankGroups = 2
Burst_Length = 2
NumOfRanks = 4
MaxColAddress = NumOfCol / 4

# Calculate bit widths
ro_bit_width = math.ceil(math.log2(MaxRowAddress))
ch_bit_width = 1
ra_bit_width = math.ceil(math.log2(NumOfRanks))
ba_bit_width = math.ceil(math.log2(NumOfBanks))
bg_bit_width = math.ceil(math.log2(NumOfBankGroups))
co_bit_width = math.ceil(math.log2(MaxColAddress))

# Bus width and request size calculations
Bus_width = 64
request_size_bytes = Bus_width / 8 * Burst_Length
shift_bits = math.log2(request_size_bytes)

def convertToPhysicalAddress(row=0, channel=0, rank=0, bank=0, bank_group=0, column=0):
    """Convert DRAM coordinates to physical address using DDR4 addressing scheme."""
    # Convert to binary and pad with zeros
    row_part = str(bin(row)[2:]).zfill(ro_bit_width)
    ch_part = str(bin(channel)[2:]).zfill(ch_bit_width)
    ra_part = str(bin(rank)[2:]).zfill(ra_bit_width)
    ba_part = str(bin(bank)[2:]).zfill(ba_bit_width)
    bg_part = str(bin(bank_group)[2:]).zfill(bg_bit_width)
    col_part = str(bin(column)[2:]).zfill(co_bit_width)

    # Handle zero-width parts
    if (ro_bit_width == 0): row_part = ''
    elif (ch_bit_width == 0): ch_part = ''
    elif (ra_bit_width == 0): ra_part = ''
    elif (ba_bit_width == 0): ba_part = ''
    elif (bg_bit_width == 0): bg_part = ''
    elif (col_part == 0): col_part = ''

    # Addressing Scheme - rochrababgco
    phy_address_bin_format_str = row_part + ch_part + ra_part + ba_part + bg_part + col_part
    
    # Convert to integer and shift for byte addressability
    phy_address_int = int(phy_address_bin_format_str, 2) << int(shift_bits)
    
    return hex(phy_address_int)

def process_chunk(chunk_data):
    """Process a chunk of data in parallel."""
    lines, start_idx, columns, num_ranks = chunk_data
    
    # Initialize tracking structures for this chunk
    address_counters = [{} for _ in range(columns)]
    generated_addresses = [set() for _ in range(columns)]
    results = [[] for _ in range(columns)]

    for i, line in enumerate(lines):
        binaries = line.strip().split('|')[:columns]
        binary_to_rank_map = {}       
        for col, base_binary in enumerate(binaries):
            binary = base_binary.zfill(28)
            #print(binary,'\n')
            # Extract components
            row = int(binary[:16], 2)
            column = int(binary[-8:], 2)
            bank = int(binary[-10:-8], 2)
            bank_group = int(binary[-12:-10], 2)

            # Check if binary is already assigned a rank
            if binary not in binary_to_rank_map:
                # Assign a rank based on the binary
                rank = 0 if num_ranks == 1 else (col + start_idx + i) % NumOfRanks
                binary_to_rank_map[binary] = rank
            else:
                # Use the previously assigned rank for the same binary
                rank = binary_to_rank_map[binary]
            
            channel = 0
            #rank = 0 if num_ranks == 1 else (col + start_idx + i) % NumOfRanks
            #print(rank)
            # Generate initial physical address
            base_address = convertToPhysicalAddress(
                row=row,
                channel=channel,
                rank=rank,
                bank=bank,
                bank_group=bank_group,
                column=column
            )

            # Handle address collisions
            current_address = base_address
            #counter = address_counters[col].get(base_binary, 0)

            #while current_address in generated_addresses[col]:
            #    if counter >= 1023:
            #        print(f"Warning: Bit flip detected in chunk {start_idx}, column {col}, line {i}")
            #       counter = 0
            #        break

            #    counter += 1
            #    new_column = (column + counter) % int(MaxColAddress)
            #    current_address = convertToPhysicalAddress(
            #        row=row,
            #        channel=channel,
            #        rank=rank,
            #       bank=bank,
            #        bank_group=bank_group,
            #        column=new_column
            #    )

           # address_counters[col][base_binary] = counter
           # generated_addresses[col].add(current_address)
            results[col].append(f"{current_address} READ 0\n")

    return results

def process_file_parallel(input_file, limit, num_ranks, output_name, chunk_size=10000):
    """Process input file in parallel using all available CPU cores."""
    try:
        # Read input file
        with open(input_file, 'r') as f:
            if limit:
                lines = list(islice(f, limit))
            else:
                lines = f.readlines()

        # Determine number of columns
        columns = min(5, len(lines[0].strip().split('|')))
        
        # Calculate chunks
        num_chunks = max(1, len(lines) // chunk_size)
        chunks = np.array_split(lines, num_chunks)
        
        # Prepare chunk data for parallel processing
        chunk_data = [(chunk.tolist(), i * chunk_size, columns, num_ranks) 
                     for i, chunk in enumerate(chunks)]

        # Create output files
        output_files = [open(f"{output_name}{col}_x16.txt", 'w') for col in range(columns)]

        try:
            # Process chunks in parallel
            with mp.Pool() as pool:
                for i, chunk_results in enumerate(pool.imap_unordered(process_chunk, chunk_data)):
                    # Write results to files
                    for col in range(columns):
                        output_files[col].writelines(chunk_results[col])
                    
                    # Progress indicator
                    processed_lines = min((i + 1) * chunk_size, len(lines))
                    print(f"Processed approximately {processed_lines:,} lines...")

        finally:
            # Close output files
            for f in output_files:
                f.close()

    except FileNotFoundError:
        print(f"Error: Input file '{input_file}' not found.")
    except Exception as e:
        print(f"Error processing file: {str(e)}")
        raise

def main():
    """Main function with example usage"""
    # Example parameters
    input_file = "/p/pd/pim/lineordersf1.tbl"
    limit = 750000
    num_ranks = 4
    output_name = "/p/pd/pim/newarchitecture/test_with_communication_to_cpu/8channel/morebankchange/sensitivity_results/lineorder_LatencyRankoptd_ch1_sf1_C"    
    print(f"Starting to process file: {input_file}")
    print(f"Processing up to {limit} lines with {num_ranks} ranks")
    print(f"Using {mp.cpu_count()} CPU cores")
    
    process_file_parallel(input_file, limit, num_ranks, output_name)

    input_file = "/p/pd/pim/lineordersf10.tbl"
    limit = 7500000
    num_ranks = 4
    output_name = "/p/pd/pim/newarchitecture/test_with_communication_to_cpu/8channel/morebankchange/sensitivity_results/lineorder_LatencyRankoptd_ch1_sf10_C"    
    print(f"Starting to process file: {input_file}")
    print(f"Processing up to {limit} lines with {num_ranks} ranks")
    print(f"Using {mp.cpu_count()} CPU cores")
        
    process_file_parallel(input_file, limit, num_ranks, output_name)

    input_file = "/p/pd/pim/lineordersf100.tbl"
    limit = 75000000
    num_ranks = 4
    output_name = "/p/pd/pim/newarchitecture/test_with_communication_to_cpu/8channel/morebankchange/sensitivity_results/lineorder_LatencyRankoptd_ch1_sf100_C"    
    print(f"Starting to process file: {input_file}")
    print(f"Processing up to {limit} lines with {num_ranks} ranks")
    print(f"Using {mp.cpu_count()} CPU cores")
    
    process_file_parallel(input_file, limit, num_ranks, output_name)
    print("Processing complete!")

if __name__ == "__main__":
    main()
