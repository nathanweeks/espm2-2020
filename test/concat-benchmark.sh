#!/bin/sh
# USAGE
#     sh concat-benchmark.sh
#
# DESCRIPTION
#     Generate benchmark-ft.tsv.bz2 and benchmark-no_ft.tsv.bz2 from
#     "make benchmark" result directories. Should be run from
#     $SCRATCH/benchmark

for dir in no_ft ft
do
  {
    printf 'num_images\tthis_image\tstat\trep\ttime.form_team\ttime.change_team\ttime.end_team\n'
    for np in 2 4 8 16 32 64
    do
      awk -v OFS='\t' '{print np,$1,$2,$3,$4,$5,$6}' np=${np} ${dir}/${np}/*/*/stdout
    done
  } | bzip2 > benchmark-${dir}.tsv.bz2
done
