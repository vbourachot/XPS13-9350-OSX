#!/bin/bash

# disassemble.sh
#
# Creates DSL files from raw Linux extract
#
# Part of DSDT paching process for Haswell Envy 15
#
# Created by RehabMan
#

set -x

if [ ! -d "tmp" ]; then
    mkdir ./tmp
fi
if [ -e tmp/* ]; then
    rm ./tmp/*
fi

cp ./origin/DSDT.aml ./origin/SSDT* ./tmp
chmod +w ./tmp/*
cd ./tmp
list=`echo *`

for aml in $list; do
    /usr/local/bin/iasl -fe ../patches/refs.txt -p ../unpatched/${aml%.*}.dsl -e ${list//$aml/} -d $aml
done

# workaround for ssdt-5 and -14 (do not include refs.txt)
/usr/local/bin/iasl -p ../unpatched/SSDT-5.dsl -e ${list//$aml/} -d SSDT-5.aml
/usr/local/bin/iasl -p ../unpatched/SSDT-14.dsl -e ${list//$aml/} -d SSDT-14.aml

cd ..
rm -R tmp
