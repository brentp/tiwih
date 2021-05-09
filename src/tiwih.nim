import tables
import strformat
import ./tiwihpkg/highcov
import os

proc main() =

  type pair = object
    f: proc(args:seq[string])
    description: string

  var dispatcher = {
    "highcov": pair(f:highcov_main, description:"report high-coverage regions in a bam/cram"),
    }.toOrderedTable

  var args = commandLineParams()

  if len(args) == 0 or not (args[0] in dispatcher):
    stderr.write_line "\nCommands: "
    for k, v in dispatcher:
      echo &"  {k:<13}:   {v.description}"
    if len(args) > 0 and (args[0] notin dispatcher) and args[0] notin @["-h", "-help"]:
      echo &"unknown program '{args[0]}'"
    quit ""

  dispatcher[args[0]].f(args[1..^1])


when isMainModule:
  main()
