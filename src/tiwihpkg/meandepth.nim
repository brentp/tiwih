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

proc region_depth*(bam:Bam, target:Target, start:int, depths: var seq[int32], adjustable_start:bool=false) =
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

    let z = depths.len - n
    if n < 10_000: return -1

    # if few bases were uncovered, then we use the full set
    # of bases and denominator. otherwise, use covered bases.
    # this makes it more likely to work for exomes.
    if z.float64 < 0.40 * depths.len.float64:
      n = depths.len

    S /= n.float64
    return int(0.5 + S)


proc estimate_mean_depth*(bam:Bam): int =
  var size = 1_000_000
  randomize()

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

proc meandepth_main*(args:seq[string]=commandLineParams()) =

  var p = newParser("meandepth"):
    option("-t", "--threads", help="cram/bam decompression threads (useful up to 4)", default="1")
    arg("bam")

  try:
    var opts = p.parse(args)
    var bam:Bam
    if not bam.open(opts.bam, threads=parseInt(opts.threads), index=true):
      quit &"[meandepth] couldn't open bam/cram: {opts.bam}"

    var o = SamField.SAM_FLAG.int or SamField.SAM_POS.int or SamField.SAM_MAPQ.int or SamField.SAM_CIGAR.int
    discard bam.set_option(FormatOption.CRAM_OPT_REQUIRED_FIELDS, o)
    discard bam.set_option(FormatOption.CRAM_OPT_DECODE_MD, 0)

    stdout.write_line $(bam.estimate_mean_depth())
  except UsageError as e:
    stderr.write_line(p.help)
    stderr.write_line(getCurrentExceptionMsg())
    quit(1)


when isMainModule:
  meandepth_main()
