#!/bin/bash
# USAGE
#     sh concat-sole_survivor.sh
#
# DESCRIPTION
#     Generate concat-sole_survivor.tsv.bz2 from "make benchmark"
#     result directories. Should be run from $SCRATCH/sole_survivor

{
  printf 'num_images\tactive_images\ttime.form_team\ttime.change_team\ttime.end_team\n'
  for np in 2 4 8 16 32 64
  do
    cat rep*/${np}/1/rank.${np//[0-9]/0}/stdout | tr ' ' '\t'
  done
} | bzip2 > sole_survivor.tsv.bz2
