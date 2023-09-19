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
    echo "USAGE: $0 [-o]

DESCRIPTION
    This script find all files ending with [.vcf.gz] in current directory and adding the reference header in them.
    Results vcf with added header line also get index by tabix.
    The output will be placed in <timestamp>_vcf_wRef directory unless specified otherwise through -o by user.

    prerequisite programs:
        parallel
        bgzip
        tabix

        -o      output for vcf with header

    " 1>&2 ;
}

help() {
    usage
    exit 65
}

timestamp=$(date +%y%m%d%H%M%S)

while getopts "o::h" o;
do
    case $o in
        o) OUTDIR=$OPTARG ;;
        h) help ;;
    esac
done;
shift $((OPTIND - 1))




# line to add in the header of vcf
reference="##reference=hg19.fasta"

# This script assumes that all vcf in directory
# end with ".vcf.gz" and properly gzipped.

# getting list of basename of files suffix with ".vcf.gz"
# Abort if no file found.
find . -maxdepth 1 -name '*.vcf.gz' -exec basename -s ".vcf.gz" {} \; > .addref.${timestamp}.tmp
vcfCount=$(wc -l .addref.${timestamp}.tmp | cut -f1 -d ' ')
echo "[INFO]: Found ${vcfCount} vcf files in current directory."
if [ "$vcfCount" == 0 ]
then
    echo "Abort"
    rm .addref.${timestamp}.tmp
    exit 65
fi

# print result dir for this run
if [ -n "$OUTDIR" ]
then
   if [ ! -d "$OUTDIR" ]
   then
        mkdir $OUTDIR
   fi
   outdir=${OUTDIR}
else
   mkdir ${timestamp}_vcf_wRef
   outdir=${timestamp}_vcf_wRef
fi;
echo "[INFO]: Result directory is ${outdir}"

# loop through list of vcf file
# and add reference line to the header
cat .addref.${timestamp}.tmp | \
    parallel -j 1 --joblog ${outdir}/filelog.log "
        zcat {}.vcf.gz | sed '/^#CHROM*/i \\${reference}' > \\${outdir}/{}_wRef.vcf ;
        bgzip -@ 16 \\${outdir}/{}_wRef.vcf ;
        tabix -p vcf \\${outdir}/{}_wRef.vcf.gz ;"

# cleanup
mv .addref.${timestamp}.tmp ${outdir}



