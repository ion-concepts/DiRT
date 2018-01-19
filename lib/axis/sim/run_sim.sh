#!/bin/bash -i
CURRENTDIR=$(pwd)
BASEDIR=$(dirname $0)
FULLDIR=$CURRENTDIR/$BASEDIR
echo $CURRENTDIR
echo $BASEDIR
echo $FULLDIR


# Move to script directory
cd $FULLDIR

#Setup vivado
#viv2019.2.1
viv2020.2

# Build libraries
#vsim -batch -do run_all.tcl -logfile vsim.log
#if [ $? -ne 0 ]; then exit 1 ; fi
#xvlog --log build_lib.log -sv -f ./extra_files.f -f .svunit.f --define SVUNIT_VERSION='"SVUnit v3.33"'  


# Check for errors
#python check_output.py
#if [ $? -ne 0 ]; then exit 1 ; fi


# Setup SVUnit
pushd ../../../tools/svunit/ # 2>&1 > /dev/null
source Setup.bsh
popd # 2>&1 > /dev/null

# Run SVUnit tests
pushd .. # 2>&1 > /dev/null
#runSVUnit -s verilator -r "-L axi" -f ../script/extra_files.f -o ../script
echo "runSVUnit"
runSVUnit -s xvlog -o . -f ./sim/extra_files.f 
if [ $? -ne 0 ]; then exit 1 ; fi
popd # 2>&1 > /dev/null

# Check for SVUnit failures
if [ $(grep -o FAILED run.log | wc -l) -ne 0 ]; then exit 1; fi

# Check for ModelSim errors
# python check_output.py run.log
exit $?
