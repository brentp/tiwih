import argparse
import hts
import strformat
import strutils

proc samplename_main*(args:seq[string]=commandLineParams()) =

  var p = newParser("samplename"):
    arg("bam")

  try:
    var opts = p.parse(args)
    var bam:Bam
    if not bam.open(opts.bam):
      quit &"[meandepth] couldn't open bam/cram: {opts.bam}"
    var found = 0
    for l in ($bam.hdr).split('\n'):
      if not l.startswith("@RG"): continue
      for t in l.split('\t'):
        if t.startswith("SM:"):
          var p = t.split(':')
          echo p[1]
          found += 1
    doAssert found == 1, &"[samplename] found {found} sample names (SM read-group tags in bam header), expected exactly one."

  except UsageError as e:
    stderr.write_line(p.help)
    stderr.write_line(getCurrentExceptionMsg())
    quit(1)


when isMainModule:
  samplename_main()
