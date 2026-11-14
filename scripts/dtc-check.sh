#!/bin/bash
# dtc-check.sh <tree> <dts> <incdir...>: preprocess + compile a DTS (sanity check)
set -euo pipefail
tree=$1 dts=$2; shift 2
inc=(); for d in "$@"; do inc+=(-I "$tree/$d"); done
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp "${inc[@]}" "$dts" \
	| dtc -@ -I dts -O dtb -o /dev/null -W no-unit_address_vs_reg -
