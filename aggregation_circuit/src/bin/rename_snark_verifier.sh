#!/bin/bash

# Check if a file name is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <solidity filename>"
    exit 1
fi

# File to be modified
FILE="$1"

# The first and third line are empty
# Remove the first and third line from the file
sed '1d;3d' $FILE > "$FILE.0"

base_name=$(basename $FILE)
if [ $base_name == "39cb264c605428fc752e90b6ac1b77427ab06b795419a759e237e283b95f377f.sol" ]; then
    # Replace 'contract Halo2Verifier' with 'contract WorldcoinGroth16Verifier'
    new_file="WorldcoinGroth16Verifier.sol"
    sed "s/contract Halo2Verifier/contract WorldcoinGroth16Verifier/g" "$FILE.0" > $new_file
    rm -f $FILE.0
else
    echo "Unknown file"
    exit 1
fi

echo "Modifications complete. New file output to $new_file"
rm -f "$FILE.0"

echo "To diff is:"
diff $FILE $new_file

echo "Running forge fmt on $new_file"
forge fmt $new_file
