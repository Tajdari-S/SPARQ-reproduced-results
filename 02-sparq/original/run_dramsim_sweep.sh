#!/bin/bash

# Output report file
REPORT_FILE="sensitivity_results/Sensitivity_dramsim_report_x16_correct_tCCDS1_tCCDL2.txt"

# Clear the report file if it exists
> "${REPORT_FILE}"

# Loop through all input files matching the pattern
for input_file in /p/pd/pim/newarchitecture/test_with_communication_to_cpu/8channel/morebankchange/sensitivity_results/lin*_L*16.txt; do
    # Skip if no files found
    [[ -f "$input_file" ]] || continue
    
    echo "Processing ${input_file}..."
    
    # Run the DRAMsim command
    /p/pd/pim/dramsimtest/DRAMsim3/build/dramsim3main \
        /p/pd/pim/dramsimtest/DRAMsim3/configs/DDR4_8Gb_x16_3200.ini \
        -c 999990000 \
        -t "${input_file}"

    # Get the base name of the input file (without path)
    base_name=$(basename "${REPORT_FILE}")
    base_name1=$(basename "${input_file}")
    
    # Copy dramsim3.txt to sensitivity_results with input filename prefix
    cp dramsim3.txt "sensitivity_results/${base_name%.*}_${base_name1%.*}dramsim3.txt"    
    
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
