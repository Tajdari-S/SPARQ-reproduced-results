import sys
import json

def dictionary_coding(input_data):
    unique_values = list(set(input_data))
    encoding_dict = {value: format(index, '032b') for index, value in enumerate(unique_values)}
    coded_data = [encoding_dict[value] for value in input_data]
    return encoding_dict, coded_data

def main(input_filename, output_filename, dict_filename):
    # Read input table
    with open(input_filename, 'r') as input_file:
        lines = input_file.readlines()

    # Separate lines into columns
    input_data = [line.strip().split('|')[:-1] for line in lines]

    # Perform dictionary coding for each column
    encoding_dicts = []
    coded_data_columns = []

    for col_index in range(len(input_data[0])):
        col_values = [row[col_index] for row in input_data]
        encoding_dict, coded_data = dictionary_coding(col_values)
        encoding_dicts.append(encoding_dict)
        coded_data_columns.append(coded_data)

    # Write output table with coded data in 16-bit binaries
    with open(output_filename, 'w') as output_file:
        for row_index in range(len(lines)):
            for col_index in range(len(input_data[0])):
                output_file.write(f'{coded_data_columns[col_index][row_index]}|')
            output_file.write('\n')  # Add newline character at the end of each row

    # Store dictionary coding information in a separate file
    with open(dict_filename, 'w') as dict_file:
        for col_index, encoding_dict in enumerate(encoding_dicts):
            json.dump({f'Column_{col_index + 1}': encoding_dict}, dict_file, indent=2)
            dict_file.write('\n')

    print(f'\nOutput table "{output_filename}" with coded data has been generated.')
    print(f'Dictionary coding information has been stored in "{dict_filename}".')

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python script_name.py input_filename output_filename dict_filename")
    else:
        input_file = sys.argv[1]
        output_file = sys.argv[2]
        dict_file = sys.argv[3]
        main(input_file, output_file, dict_file)
