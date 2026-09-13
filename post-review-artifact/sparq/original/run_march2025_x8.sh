#!/bin/bash

# Output report file
REPORT_FILE="dramsim_report_ccqsize1.txt"

# Clear the report file if it exists
> "${REPORT_FILE}"

# Loop through all input files matching the pattern
for input_file in ./lin*; do
    # Skip if no files found
    [[ -f "$input_file" ]] || continue
    
    echo "Processing ${input_file}..."
    
    # Run the DRAMsim command
    /p/pd/pim/dramsimtest/DRAMsim3/build/dramsim3main \
        /p/pd/pim/dramsimtest/DRAMsim3/configs/DDR4_8Gb_x8_3200.ini \
        -c 2999990000 \
        -t "${input_file}"
    
    # Append a separator line to the report
    echo "----------------------------------------" >> "${REPORT_FILE}"
    
    # Append the input filename to the report
    echo "${input_file}" >> "${REPORT_FILE}"
    echo "${input_file}"     
    # Extract and append the num_read_cmds line from dramsim3.txt
    grep "num_read_cmds" dramsim3.txt >> "${REPORT_FILE}"
    
    # Extract and append the last 'read' line from dramsim3ch_0cmd.trace
    tac dramsim3ch_0cmd.trace | grep -m 1 "read" >> "${REPORT_FILE}"
    
    # Add a blank line for readability
    echo "" >> "${REPORT_FILE}"
    
    # Optional: wait a bit between runs to ensure files are properly closed
    sleep 0.01
done

echo "Report generation complete. Results saved in ${REPORT_FILE}"
