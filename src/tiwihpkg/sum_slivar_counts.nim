import hts
import strformat
import tables
import argparse
import strutils
import tables

proc all_zero(a:seq[int]): bool =
  for v in a:
    if v != 0: return false
  return true

proc sum_slivar_counts(counts_files:seq[string], drop_zero_samples: bool) =

  var fhs = newSeq[File](counts_files.len)
  var header_line: string
  for i, f in counts_files:
    if not fhs[i].open(f):
      quit &"couldn't open counts file: {f}"
    if i == 0:
      header_line = fhs[i].readLine.strip(chars={'#'})
    else:
      doAssert fhs[i].readLine == header_line, "tiwih: require mathcing headers for sum-slivar-counts"
  defer:
    for f in fhs: f.close()

  var header = header_line.strip(chars={'#', '\n', '\r', ' '}).split("\t")

  var counts = newTable[string, seq[int]]()
  var sample_order = newSeq[string]()
  for i, fh in fhs:
    # note we read header above
    for line in fh.lines:
      var toks = line.strip(chars={'#', '\n', '\r', ' '}).split("\t")
      var ints = newSeq[int](toks.len - 1)
      for k, t in toks[1..toks.high]: ints[k] = parseInt(t)
      if i == 0:
        doAssert toks[0] notin counts
        sample_order.add(toks[0])
        counts[toks[0]] = ints
      else:
        var old = counts[toks[0]]
        doAssert old.len == ints.len
        for i, n in ints:
          old[i] += n
        counts[toks[0]] = old

  stdout.write_line '#', header_line
  for sample in sample_order:
    let sample_counts = counts[sample]
    if drop_zero_samples and all_zero(sample_counts):
      continue
    var line = newSeq[string](sample_counts.len + 1)
    line[0] = sample
    for i, n in sample_counts:
      line[i + 1] = $n
    stdout.write_line line.join("\t")

proc sum_slivar_counts_main*(args:seq[string]=commandLineParams()) =

  var p = newParser("sumslivarcounts"):
    flag("-z", "--drop-zero-samples", help="dont write samples with all zero counts")
    arg("counts", nargs= -1, help="slivar summary files")

  try:
    var opts = p.parse(args)
    if opts.help:
      quit 0
    if opts.counts.len == 0:
      raise newException(UsageError, "specify one or more counts files")

    sum_slivar_counts(opts.counts, opts.drop_zero_samples)

  except UsageError as e:
    stderr.write_line(p.help)
    stderr.write_line(getCurrentExceptionMsg())
    quit 1

when isMainModule:
  sum_slivar_counts_main()
