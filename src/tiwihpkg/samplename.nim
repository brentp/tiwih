import argparse
import hts
import sets
import strformat
import strutils

proc samplename*(bam:Bam): seq[string] =

  var found = initHashSet[string]()
  for l in ($bam.hdr).split('\n'):
    if not l.startswith("@RG"): continue
    for t in l.split('\t'):
      if t.startswith("SM:"):
        var p = t.split(':')
        if p[1] notin found:
          result.add(p[1])
          found.incl(p[1])

proc samplename_main*(args:seq[string]=commandLineParams()) =

  var p = newParser("samplename"):
    arg("bam")

  try:
    var opts = p.parse(args)
    if opts.help:
      quit 0
    var bam:Bam
    if not bam.open(opts.bam):
      quit &"[meandepth] couldn't open bam/cram: {opts.bam}"

    var found = bam.samplename
    doAssert found.len == 1, &"[samplename] found {found} sample names (SM read-group tags in bam header), expected exactly one."
    echo found[0]
  except UsageError:
    stderr.write_line(p.help)
    stderr.write_line(getCurrentExceptionMsg())
    quit(1)


when isMainModule:
  samplename_main()
