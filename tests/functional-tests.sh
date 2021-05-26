#!/bin/bash
test -e ssshtest || wget -q https://raw.githubusercontent.com/ryanlayer/ssshtest/master/ssshtest

. ssshtest

set -o nounset

exe=./tiwih_test
rm -f $exe

nim c -o:$exe -d:debug  -d:useSysAssert -d:useGcAssert --lineDir:on --debuginfo --boundChecks:on -x:on src/tiwih


run check_help_works $exe --help
assert_exit_code 0
assert_in_stdout "Commands:"

run check_combine_slivar $exe combine_slivar_counts tests/a.summary.txt tests/a.ch.summary.txt
assert_in_stdout "#sample	denovo	recessive	x_denovo	x_recessive	dominant	compound-het
150423	0	0	0	0	0
150424	14	18	0	0	18	4
150426	0	0	0	0	0"

run check_combine_slivar_drop_zero $exe combine_slivar_counts --drop-zero-samples tests/a.summary.txt tests/a.ch.summary.txt
assert_in_stdout "#sample	denovo	recessive	x_denovo	x_recessive	dominant	compound-het
150424	14	18	0	0	18	4"

run check_sum_slivar $exe sum_slivar_counts tests/a.summary.txt tests/a.summary.txt
assert_in_stdout "#sample	comphet_side	denovo	recessive	x_denovo	x_recessive	dominant
150423	0	0	0	0	0	0
150424	5274	28	36	0	0	36
150426	0	0	0	0	0	0"
assert_exit_code 0

run check_sum_slivar_drop_zero $exe sum_slivar_counts tests/a.summary.txt tests/a.summary.txt -z
assert_in_stdout "#sample	comphet_side	denovo	recessive	x_denovo	x_recessive	dominant
150424	5274	28	36	0	0	36"
assert_exit_code 0

