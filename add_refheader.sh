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

# This script assumes that all vcf in directory
# end with ".vcf.gz" and properly gzipped.
timestamp=$(date +%y%m%d%H%M%S)

# line to add in the header of vcf
reference="##reference=hg19.fasta"

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

# create new directory for new vcf
mkdir ${timestamp}_vcf_wRef
echo "[INFO]: Result directory is ${timestamp}_vcf_wRef."

# loop through list of vcf file
# and add reference line to the header
cat .addref.${timestamp}.tmp | \
    parallel -j 1 --joblog ${timestamp}_vcf_wRef/filelog.log "
        zcat {}.vcf.gz | sed '/^#CHROM*/i \\${reference}' > \\${timestamp}_vcf_wRef/{}_wRef.vcf ;
        bgzip -@ 16 \\${timestamp}_vcf_wRef/{}_wRef.vcf ;
        tabix -p vcf \\${timestamp}_vcf_wRef/{}_wRef.vcf.gz ;"

# cleanup
mv .addref.${timestamp}.tmp ${timestamp}_vcf_wRef
