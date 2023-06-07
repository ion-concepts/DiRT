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
if [ "$#" -ne 1 ]; then
    echo 'USAGE: run_unit.sh <relative_dir> '
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


# Setup SVUnit
pushd ../../tools/svunit/ # 2>&1 > /dev/null
source Setup.bsh
popd # 2>&1 > /dev/null

# Run SVUNIT
echo "runSVUnit"
runSVUnit -s modelsim --c_arg "-incdir ../../global -incdir ../../axis" -f dependencies.f -o sim
#runSVUnit -s xsim -o sim --c_arg "-include ../../global -include ../../axis" --r_arg " work.testrunner --R " # "work.testrunner --R --gui"
if [ $? -ne 0 ]; then exit 1 ; fi
popd # 2>&1 > /dev/null


