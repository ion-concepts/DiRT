#!/bin/bash
#
# Author Ian Buckley, Ion Concepts LLC.
#
# License: CERN-OHL-P (See LICENSE.md)
#

# Find directory that contains this script
BASEDIR=$(dirname $0)

# Check command line args
if [ "$#" -ne 1 ]; then
    echo 'USAGE: build_lib.sh <relative_dir_to_build> '
    exit 1
fi
# Test if directory to build library from exists
BUILDDIR=$BASEDIR/$1
if [ ! -d $BUILDDIR ]; then
    echo 'build_lib.sh: Build directory does not exist'
    exit 1
fi
# Move to build dir
cd $BUILDDIR
# Test for list of files to build library from
if [ ! -e files.f ]; then
    echo 'build_lib.sh: No files.f in' $BUILDDIR
    exit 1
fi
# Build library. Name library after directory
xvlog --log ../build_lib.log -sv -f files.f -work $1 -include ../global -include ../axis
# Exit with exit code from Verilog
exit $?
