import hts
import strformat
import argparse
import strutils
import tables

proc combine_slivar_counts(counts:string, counts_ch:string, drop: var seq[string]) =

  var cfh: File
  if not cfh.open(counts):
    quit "couldn't open counts file"

  var hfh: File
  if not hfh.open(counts_ch):
    quit "couldn't open counts-ch file"


  var header = cfh.readLine().strip(chars={'#', '\n', '\r', ' '}).split("\t")
  var chheader = hfh.readLine().strip(chars={'#', '\n', '\r', ' '}).split("\t")

  var drop_idxs = newSeqOfCap[int](drop.len)
  for d in drop:
    if d in header:
      drop_idxs.add(header.find(d))

  var newheader = newSeq[string]()
  for h in header:
    if h in drop: continue
    newheader.add(h)
  for i, h in chheader:
    if i == 0: continue
    newheader.add(h)
  stdout.write_line '#' & newheader.join("\t")

  for line in cfh.lines:
      var toks = line.strip(chars={'#', '\n', '\r', ' '}).split("\t")
      var ctoks = hfh.readLine().strip(chars={'#', '\n', '\r', ' '}).split("\t")
      doAssert toks[0] == ctoks[0], &"expecting same sample order, got {toks[0]} and {ctoks[0]}"
      var line = newSeq[string]()
      for i, t in toks:
        if i in drop_idxs: continue
        line.add(t)
      for i, t in ctoks:
        if i == 0: continue
        line.add(t)

      stdout.write_line line.join("\t")

proc combine_slivar_counts_main*(args:seq[string]=commandLineParams()) =

  var p = newParser("combineslivarcounts"):
    option("-d", "--drop", multiple=true, help="fields to drop")
    arg("counts", nargs=1, help="slivar summary file from original query")
    arg("ch_counts", nargs=1, help="slivar summary file from compound het query")

  try:
    var opts = p.parse(args)
    if opts.help:
      quit 0

    if opts.drop.len == 0:
      opts.drop.add("comphet_side")

    combine_slivar_counts(opts.counts, opts.ch_counts, opts.drop)

  except UsageError as e:
    stderr.write_line(p.help)
    stderr.write_line(getCurrentExceptionMsg())
    quit 1


when isMainModule:
  combine_slivar_counts_main()
