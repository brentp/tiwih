import argparse
import algorithm
import os
import strutils
import strformat
import random
import hts
import math

type pair = tuple[pos: int, value: int32]

iterator gen_start_ends(c: Cigar, ipos: int): pair {.inline.} =
  # generate start, end pairs given a cigar string and a position offset.
  if c.len == 1 and c[0].op == CigarOp.match:
    yield (ipos, int32(1))
    yield (ipos + c[0].len, int32(-1))
  else:
    var pos = ipos
    var last_stop = -1
    var con: Consume
    for op in c:
      con = op.consumes
      if not con.reference:
        continue
      var olen = op.len
      if con.query:
        if pos != last_stop:
          yield (pos, int32(1))
          if last_stop != -1:
            yield (last_stop, int32(-1))
        last_stop = pos + olen
      pos += olen
    if last_stop != -1:
      yield (last_stop, int32(-1))

proc region_depth(bam:Bam, target:Target, start:int, depths: var seq[int32], adjustable_start:bool=false) =
    var rstart = 0
    var rstop = 0
    var i = 0
    for aln in bam.query(target.tid, start, target.length.int):
      if (aln.flag and 1796) != 0: continue

      if aln.mapping_quality < 1: continue
      if rstart == 0:
        rstart = aln.start.int
        rstop = rstart + depths.len

      if aln.start >= rstop: break
      for p in aln.cigar.gen_start_ends(max(0, aln.start.int - (if adjustable_start: rstart else: start))):
        let pos = max(0, p.pos)
        if pos >= depths.len: break
        depths[pos] += p.value
    depths.cumsum

proc mean(depths: var seq[int32]): int =
    var S = 0'f64
    var n = 0
    for d in depths:
      S += d.float64
      n += int(d > 0)
    S /= n.float64
    if n < 10_000: return -1
    return int(0.5 + S)


proc estimate_mean_depth(bam:Bam): int =
  var size = 1_000_000

  var mean_depths: seq[int]
  var depths = newSeq[int32](size)
  for target in bam.hdr.targets:
    if target.name.endsWith("decoy") or target.name == "hs37d5" or target.name.endsWith("random") or target.name.endsWith("X") or target.name.endsWith("Y"): continue
    if target.length.int < 5 * size: continue
    var l = target.length.int

    # sample more from larger chroms. ~6 times for chr1
    var times = max(1, int(l / 40_000_000))
    for i in 0..<times:
      var start = rand(0..l-2 * size)
      zeroMem(depths[0].addr.pointer, depths.len * sizeof(depths[0]))
      bam.region_depth(target, start, depths, adjustable_start=true)
      var d = depths.mean()
      if d >= 0: mean_depths.add(d)

  mean_depths.sort()
  result = mean_depths[int(mean_depths.len / 2)]


iterator highcov(fbam:string, fasta_path:string, nsd:int, max_depth:int, min_length:int, threads:int=1): tuple[chrom:string, start:int, stop:int] =

  var bam:Bam

  if not bam.open(fbam, threads=threads, index=true, fai=fasta_path):
    quit &"could not open bam/cram: {fbam}"

  var opts = SamField.SAM_FLAG.int or SamField.SAM_POS.int or SamField.SAM_MAPQ.int or SamField.SAM_CIGAR.int
  discard bam.set_option(FormatOption.CRAM_OPT_REQUIRED_FIELDS, opts)
  discard bam.set_option(FormatOption.CRAM_OPT_DECODE_MD, 0)

  let mean_depth = bam.estimate_mean_depth()

  let cutoff = if max_depth < 0: int(0.5 + mean_depth.float64 + nsd.float64 * sqrt(mean_depth.float64)) else: max_depth


  stderr.write_line(&"[highcov] estimated mean depth as: {mean_depth} with high-depth cutoff of: {cutoff}")

  var size = 10_000_000
  var depths = newSeq[int32](size)
  for target in bam.hdr.targets:
    var l = target.length.int
    for start in countup(0, l, size):
      zeroMem(depths[0].addr.pointer, depths.len * sizeof(depths[0]))
      bam.region_depth(target, start, depths)

      var i = 0
      while i < depths.high:
        while depths[i] < cutoff and i < depths.high: i.inc
        let region_start = i
        while depths[i] >= cutoff and i < depths.high: i.inc
        let region_stop = i
        if region_stop - region_start > min_length:
          yield (target.name, start + region_start, start + region_stop)
        i += 1

proc highcov_main*(args:seq[string]=commandLineParams()) =

  var p = newParser("highcov"):
    option("-f", "--fasta", help="reference fasta file")
    option("-t", "--threads", help="cram/bam decompression threads (useful up to 4)", default="1")
    option("-n", default="10", help="print out regions where coverage is more than mean + n * sqrt(mean) [assumes poisson coverage]")
    option("-m", "--max-depth", help="use this depth as the cutoff. if specified, then -n arg is ignored.", default="")
    option("-l", "--min-length", help="only output regions if they have at least this length", default="100")
    arg("bam")

  try:
    var opts = p.parse(args)
    for h in highcov(opts.bam, opts.fasta, parseInt(opts.n),
                     if opts.max_depth == "": -1 else: parseInt(opts.max_depth),
                     parseInt(opts.min_length),
                     parseInt(opts.threads)):
      stdout.write_line &"{h.chrom}\t{h.start}\t{h.stop}"
  except UsageError as e:
    stderr.write_line(p.help)
    stderr.write_line(getCurrentExceptionMsg())
    quit(1)


when isMainModule:
  highcov_main()
