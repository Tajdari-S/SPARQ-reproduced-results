  GNU nano 6.2                                                         sensitivity.sh                                                                  
#!/bin/bash

# Directory for storing results
OUTPUT_DIR="sensitivity_results"
mkdir -p "$OUTPUT_DIR"

# Path to DRAMsim config file
CONFIG_FILE="/p/pd/pim/dramsimtest/DRAMsim3/configs/DDR4_8Gb_x16_3200.ini"

# Backup original config file
cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"

# Base output report file name
BASE_REPORT="Sensitivity_dramsim_report_x16_correct"

# Initial tCCD values
tCCDS=1
tCCDL=2

for i in {1..5}
do
    # Update tCCDS and tCCDL in the config file
#    sed -i "s/tCCDS = [0-9]*/tCCDS = $tCCDS/" "$CONFIG_FILE"
#sed -i "s/tCCDL = [0-9]*/tCCDL = $tCCDL/" "$CONFIG_FILE"

      sed -i "s/^[[:space:]]*tCCD_S[[:space:]]*=[[:space:]]*[0-9]*/tCCD_S = $tCCDS/" "$CONFIG_FILE"
      sed -i "s/^[[:space:]]*tCCD_L[[:space:]]*=[[:space:]]*[0-9]*/tCCD_L = $tCCDL/" "$CONFIG_FILE"

    # Set output file name with tCCD values
    REPORT_FILE="${OUTPUT_DIR}/${BASE_REPORT}_tCCDS${tCCDS}_tCCDL${tCCDL}.txt"

    # Modify run.sh to use the new report file name
    sed -i "s|REPORT_FILE=.*|REPORT_FILE=\"$REPORT_FILE\"|" run.sh

    # Run the simulation
    ./run.sh

    # Increment tCCD values for next iteration
    ((tCCDS++))
    ((tCCDL++))

    # Restore original config file for safety
    cp "${CONFIG_FILE}.backup" "$CONFIG_FILE"
done

# Clean up backup file
rm "${CONFIG_FILE}.backup"

echo "Simulations completed. Results are stored in $OUTPUT_DIR"














