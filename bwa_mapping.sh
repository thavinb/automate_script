#!/bin/bash

# Copyright 2023 THAVIN BODHARAMIK
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the “Software”),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR"  ]]; then DIR="$PWD"; fi

usage() {
    echo "USAGE: $0 [-r] [-t]

DESCRIPTION
    This script find all fastq files in current directory and mapping them to specified reference genome.
    The reference genome is expected to come with their index from bwa.

    prerequisite programs:
        parallel
        bwa
        samtools

        -r      path to reference genome.
                Index is expected to be in the same path.
        -t      Number of threads to pass to each command.
                default: 16

    " 1>&2 ;
}

help() {
    usage
    exit 65
}

while getopts "r:t::h" o;
do
    case $o in
        r) REFERENCE=$OPTARG ;;
        t) THREADS=$OPTARG ;;
        h) help ;;
    esac
done;
shift $((OPTIND - 1))


if [ -n "$REFERENCE" ]
then
   if [ -f "$REFERENCE" ]
   then
        reference=${REFERENCE}
   else
        echo "[ERROR]: Reference path: ${REFERENCE} not found!!."
        usage
        exit 65
   fi
else
    echo "[ERROR]: No reference path specified."
    usage
    exit 65
fi;



if [ -n "$THREADS" ]
then
   threads=${THREADS}
else
   threads=16
fi



# This script assumes that all fastq in directory
# end with ".fq.gz" and properly gzipped.
timestamp=$(date +%y%m%d%H%M%S)


# Getting list of basename of files suffix with ".fq.gz"
# Abort if no file found.
find . -maxdepth 1 -name '*.fq.gz' -exec basename -s ".fq.gz" {} \; | \
    sed 's/_[12]$//g' | sort | uniq > .fastqList.${timestamp}.tmp

# Sanity check
sampleCount=$(wc -l .fastqList.${timestamp}.tmp | cut -f1 -d ' ')
echo "[INFO]: Found ${sampleCount} fastq files in current directory."
if [ "$sampleCount" == 0 ]
then
    echo "Abort"
    rm .fastqList.${timestamp}.tmp
    exit 65
fi

SEcount=$(find . -maxdepth 1 -name '*.fq.gz' -exec basename -s ".fq.gz" {} \; | \
    sed 's/_[12]$//g' | sort | uniq -c | awk '$1==1{i++} END{print i}')
if [ -n "$SEcount" ]
then
    echo "[WARNING]: ${SEcount} single-ended found!."
fi

# Create new directory for mapping results
mkdir ${timestamp}_bam
echo "[INFO]: Result directory is ${timestamp}_bam."

# Loop through fastq list and map them to specified reference
cat .fastqList.${timestamp}.tmp | \
    parallel -j 1 --joblog ${timestamp}_bam/mapping.log "
        echo [INFO]: Mapping {} with \\${reference}.;
        bwa mem -R '@RG\tID:{}\tSM:{}\tPL:DNBSEQ-G99' -t \\${threads} \\${reference} {}_1.fq.gz {}_2.fq.gz | \
            samtools fixmate --threads \\${threads} - - | \
            samtools sort --threads \\${threads} -o \\${timestamp}_bam/{}.bam - ;
            samtools index \\${timestamp}_bam/{}.bam"

# cleanup
mv .fastqList.${timestamp}.tmp ${timestamp}_bam

