#!/bin/bash
#
# Author Ian Buckley, Ion Concepts LLC.
#
# License: CERN-OHL-P (See LICENSE.md)
#
# Find directory that contains this script
BASEDIR=$(dirname $0)
echo 'BASEDIR:' $BASEDIR


# Check command line args
if [ "$#" -ne 1 ] && [ "$#" -ne 2 ] ; then
    echo 'USAGE: run_unit.sh <relative_dir> [unit_test_file_name]'
    exit 1
fi

# Test if directory to build library from exists
BUILDDIR=$BASEDIR/$1
if [ ! -d $BUILDDIR/sim ]; then
    echo 'run_unit.sh: Directory to run unit tests in does not exist'
    #    exit 1
    mkdir $BUILDDIR/sim
fi

# Move to unit test directory
cd $BUILDDIR

pwd


# If we just want to run a single test then construct that command line option here
if [ "$#" -eq 2 ] ; then
    UNIT="-t $2"
    echo "Running just: $UNIT"
else
    UNIT=""
    echo "Running all tests"
fi

# Setup SVUnit
pushd ../../tools/svunit/ # 2>&1 > /dev/null
source Setup.bsh
popd # 2>&1 > /dev/null

# Run SVUNIT
echo "runSVUnit"
# NOTES:
#    -voptargs=+acc=npr causes internal nodes to not be eliminated in optimization
#    -permit_unmatched_virtual_intf solves a problem with virtual interfaces not matching any real interface
#
runSVUnit -s questa --c_arg "-incdir ../../global -incdir ../../axis -incdir ../../ethernet +libext+.sv -y ../../axis -y ../../dsp -y ../../ethernet" \
        --r_arg "-gui -permit_unmatched_virtual_intf -voptargs=+acc=npr" -f dependencies.f -o sim $UNIT
if [ $? -ne 0 ]; then exit 1 ; fi
popd # 2>&1 > /dev/null
