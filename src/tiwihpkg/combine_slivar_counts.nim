import hts
import strformat
import tables
import argparse
import strutils
import tables

proc all_zero(toks: seq[string]): bool =
  for i, t in toks:
    if i == 0: continue
    if t != "0": return false
  return true

proc combine_slivar_counts(counts:string, counts_ch:string, drop_fields: var seq[string], drop_zero_samples: bool) =

  var cfh: File
  if not cfh.open(counts):
    quit "couldn't open counts file"

  var hfh: File
  if not hfh.open(counts_ch):
    quit "couldn't open counts-ch file"

  var header = cfh.readLine().strip(chars={'#', '\n', '\r', ' '}).split("\t")
  var chheader = hfh.readLine().strip(chars={'#', '\n', '\r', ' '}).split("\t")

  var drop_idxs = newSeqOfCap[int](drop_fields.len)
  for d in drop_fields:
    if d in header:
      drop_idxs.add(header.find(d))

  var newheader = newSeq[string]()
  for h in header:
    if h in drop_fields: continue
    newheader.add(h)
  for i, h in chheader:
    if i == 0: continue
    newheader.add(h)
  stdout.write_line '#' & newheader.join("\t")

  var sample_lines = newTable[string, seq[string]]()
  # just so we can try to print in same order
  var sample_order = newSeq[string]()

  for line in cfh.lines:
      var toks = line.strip(chars={'#', '\n', '\r', ' '}).split("\t")
      doAssert toks[0] notin sample_lines, &"tiwih: error repeated sample found: {toks[0]}"
      sample_order.add(toks[0])

      var line = newSeq[string]()
      for i, t in toks:
        if i in drop_idxs: continue
        line.add(t)
      sample_lines[toks[0]] = line

  for line in hfh.lines:
      var toks = line.strip(chars={'#', '\n', '\r', ' '}).split("\t")
      doAssert toks[0] in sample_lines, &"tiwih: error sample: {toks[0]} not found in first file."

      var line = sample_lines[toks[0]]
      line.add(toks[1..toks.high])
      sample_lines[toks[0]] = line

  for sample in sample_order:
    let line = sample_lines[sample]
    if drop_zero_samples and all_zero(line):
      continue
    stdout.write_line line.join("\t")

proc combine_slivar_counts_main*(args:seq[string]=commandLineParams()) =

  var p = newParser("combineslivarcounts"):
    option("-f", "--drop-fields", multiple=true, help="fields to drop")
    flag("-z", "--drop-zero-samples", help="dont write samples with all zero counts")
    arg("counts", nargs=1, help="slivar summary file from original query")
    arg("ch_counts", nargs=1, help="slivar summary file from compound het query")

  try:
    var opts = p.parse(args)
    if opts.help:
      quit 0

    if opts.drop_fields.len == 0:
      opts.drop_fields.add("comphet_side")

    combine_slivar_counts(opts.counts, opts.ch_counts, opts.drop_fields, opts.drop_zero_samples)

  except UsageError as e:
    stderr.write_line(p.help)
    stderr.write_line(getCurrentExceptionMsg())
    quit 1


when isMainModule:
  combine_slivar_counts_main()
