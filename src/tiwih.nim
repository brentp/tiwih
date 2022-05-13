import tables
import strformat
import ./tiwihpkg/version

import ./tiwihpkg/combine_slivar_counts
import ./tiwihpkg/highcov
import ./tiwihpkg/meandepth
import ./tiwihpkg/samplename
import ./tiwihpkg/setrefallele
import ./tiwihpkg/fairegions
import ./tiwihpkg/pedbam
import ./tiwihpkg/setsvalt
import ./tiwihpkg/slivar_jigv_links
import ./tiwihpkg/slivar_jigv_tsv
import ./tiwihpkg/slivar_split_fam
import ./tiwihpkg/sum_slivar_counts
import ./tiwihpkg/vcf2bedpe
import os

proc main() =
  stderr.write_line &"[tiwih] version {tiwihVersion}"

  type pair = object
    f: proc(args:seq[string])
    description: string

  var dispatcher = {
    "combine_slivar_counts": pair(f:combine_slivar_counts_main, description:"combine counts from slivar for original call and for compound-hets"),
    #"extract_bam_region_pairs": pair(f: 
    "fairegions": pair(f:fairegions_main, description:"generate equal length regions from an fai (for parallelization)"),
    "highcov": pair(f:highcov_main, description:"report high-coverage regions in a bam/cram"),
    "meandepth": pair(f:meandepth_main, description:"quickly estimate mean coverage in a bam/cram"),
    "pedbam": pair(f:pedbam_main, description:"add a alignment path to a ped/fam file given a list of bams/crams"),
    "samplename": pair(f:samplename_main, description:"find sample-name from read-group in a bam/cram"),
    "setsvalt": pair(f:setsvalt_main, description:"set the ALT allele in a manta VCF to left + N + right for paragraph genotyper"),
    "setref": pair(f:setref_main, description:"set reference allele to actual allele from 'N'"),
    "slivar_jigv_links": pair(f:slivar_jigv_links_main, description:"add jigv links to a slivar tsv"),
    "slivar_jigv_tsv": pair(f:slivar_jigv_tsv_main, description:"generate an html file with links to existing jigv plots from a slivar tsv file"),
    "slivar_split_fam": pair(f:slivar_split_fam_main, description:"split joint slivar files by family and inheritance mode"),
    "sum_slivar_counts": pair(f:sum_slivar_counts_main, description:"from same samples split across multiple files/regions"),
    "vcf2bedpe": pair(f: vcf2bedpe_main, description: "convert and SV VCF to simple bedpe"),
    }.toOrderedTable

  var args = commandLineParams()
  when not defined(danger):
    stderr.write_line "[tiwih] compiled without optimizations, will be slow"

  if len(args) == 0 or not (args[0] in dispatcher):
    stdout.write_line "\nCommands: "
    for k, v in dispatcher:
      echo &"  {k:<13}:   {v.description}"
    if len(args) > 0 and (args[0] notin dispatcher) and args[0] notin @["-h", "-help", "--help"]:
      echo &"unknown program '{args[0]}'"
    else:
      quit 0
    quit ""

  var cargs = args[1..^1]
  if cargs.len == 0: cargs = @["--help"]
  dispatcher[args[0]].f(cargs)


when isMainModule:
  main()
