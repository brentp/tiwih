import tables
import strformat
import ./tiwihpkg/version

import ./tiwihpkg/highcov
import ./tiwihpkg/meandepth
import ./tiwihpkg/samplename
import ./tiwihpkg/setrefallele
import os

proc main() =
  stderr.write_line &"[tiwih] version {tiwihVersion}"

  type pair = object
    f: proc(args:seq[string])
    description: string

  var dispatcher = {
    "highcov": pair(f:highcov_main, description:"report high-coverage regions in a bam/cram"),
    "meandepth": pair(f:meandepth_main, description:"quickly estimate mean coverage in a bam/cram"),
    "samplename": pair(f:samplename_main, description:"find sample-name from read-group in a bam/cram"),
    "setref": pair(f:setref_main, description:"set reference allele to actual allele from 'N'"),
    }.toOrderedTable

  var args = commandLineParams()
  when not defined(danger):
    stderr.write_line "[tiwih] compiled without optimizations, will be slow"

  if len(args) == 0 or not (args[0] in dispatcher):
    stderr.write_line "\nCommands: "
    for k, v in dispatcher:
      echo &"  {k:<13}:   {v.description}"
    if len(args) > 0 and (args[0] notin dispatcher) and args[0] notin @["-h", "-help"]:
      echo &"unknown program '{args[0]}'"
    quit ""

  var cargs = args[1..^1]
  if cargs.len == 0: cargs = @["--help"]
  dispatcher[args[0]].f(cargs)


when isMainModule:
  main()
