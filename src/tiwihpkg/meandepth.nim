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

proc region_depth*(bam:Bam, target:Target, start:int, depths: var seq[int32], adjustable_start:bool=false): bool =
    var rstart = 0
    var rstop = 0
    var i = 0
    for aln in bam.query(target.tid, start, target.length.int):
      if (aln.flag and 1796) != 0: continue

      if aln.mapping_quality < 1: continue
      if i == 0:
        if adjustable_start:
          rstart = max(start, aln.start.int)
          # don't allow to skip too far. can lead to weird behavior where it jumps to
          # same high-coverage area for acrocentric chroms.
          if rstart - start > depths.len:
            return false  # depths is empty
        else:
          rstart = start
        rstop = rstart + depths.len
      i.inc
      if aln.start >= rstop: break
      for p in aln.cigar.gen_start_ends(aln.start.int - rstart):
        let pos = max(0, p.pos)
        if pos >= depths.len: break
        depths[pos] += p.value
    depths.cumsum
    return true

proc mean(depths: var seq[int32]): int =
    var S = 0'f64
    var n = 0
    for d in depths:
      S += d.float64
      n += int(d > 0)
    #echo depths[depths.high]

    let z = depths.len - n
    if n.float < 0.1 * depths.len.float: return -1

    # if few bases were uncovered, then we use the full set
    # of bases and denominator. otherwise, use covered bases.
    # this makes it more likely to work for exomes.
    if z.float64 < 0.40 * depths.len.float64:
      n = depths.len

    S = S / n.float64
    return int(0.5 + S)


proc estimate_mean_depth*(bam:Bam, chrom:string=""): int =
  ## estimate the mean depth of a chromosome (or region) by sampling.
  var size = 1_024
  randomize(41)

  var mean_depths: seq[int]
  for target in bam.hdr.targets:
    if chrom != "":
      if chrom != target.name: continue
    else:
      if target.name.endsWith("decoy") or target.name == "hs37d5" or target.name.endsWith("random") or target.name.endsWith("X") or target.name.endsWith("Y"): continue
      if target.length.int < 5 * size: continue

    if chrom != "" and target.name != chrom:
      raise newException(KeyError, &"chromosome {chrom} not found in bam/cram header")

    var l = target.length.int

    # sample more from larger chroms. ~40 times for chr1
    var times = max(1, int(l / 6_000_000))
    if chrom != "": times *= 10
    var tries = 0
    while mean_depths.len < times and tries < times * 2:
      tries.inc
      var start = rand(0..l-2 * size)
      var depths = newSeq[int32](size)
      if bam.region_depth(target, start, depths, adjustable_start=true):
        var d = depths.mean()
        if d >= 0: mean_depths.add(d)

  mean_depths.sort()
  result = mean_depths[int(mean_depths.len / 2)]

proc read_length(f:string): int =
  let skip_bases = 10_000_000
  let samples = 10_000
  var sizes = newSeqofCap[int](samples)
  var bam:Bam
  if not bam.open(f, threads=1):
    quit &"[meandepth] couldn't open bam/cram: {f}"
  var o = SamField.SAM_FLAG.int or SamField.SAM_POS.int or SamField.SAM_MAPQ.int or SamField.SAM_CIGAR.int
  discard bam.set_option(FormatOption.CRAM_OPT_REQUIRED_FIELDS, o)
  discard bam.set_option(FormatOption.CRAM_OPT_DECODE_MD, 0)
  var n_bases = 0
  for b in bam:
    var rl = 0
    for op in b.cigar:
      rl += op.len * int(op.consumes.query)
    n_bases += rl
    if n_bases >= skip_bases:
      sizes.add(rl)
    if sizes.len == samples: break

  sizes.sort()
  return sizes[int(sizes.len / 2)]


proc meandepth_main*(args:seq[string]=commandLineParams()) =

  var p = newParser("meandepth"):
    flag("-r", "--scale-by-read-length", help="divide mean-depth by read-length (https://github.com/DecodeGenetics/graphtyper/wiki/User-guide#subsampling-reads-in-abnormally-high-sequence-depth)")
    option("--chromosome", help="optional chromosome to restrict depth calculation. can specify list of comma-separted chromosomes")
    arg("bam", nargs=1)

  try:
    var opts = p.parse(args)
    if opts.help:
      quit 0
    var bam:Bam
    if not bam.open(opts.bam, threads=1, index=true):
      quit &"[meandepth] couldn't open bam/cram: {opts.bam}"

    var o = SamField.SAM_FLAG.int or SamField.SAM_POS.int or SamField.SAM_MAPQ.int or SamField.SAM_CIGAR.int
    discard bam.set_option(FormatOption.CRAM_OPT_REQUIRED_FIELDS, o)
    discard bam.set_option(FormatOption.CRAM_OPT_DECODE_MD, 0)

    var chroms = opts.chromosome.split(",")
    if chroms.len == 0: chroms.add("")
    for chrom in chroms:
      let d = bam.estimate_mean_depth(chrom)
      let prefix = if chroms[0] != "": &"{chrom}\t" else: ""
      if opts.scale_by_read_length:
        let rl = read_length(opts.bam)
        echo &"{prefix}{d/rl:.3f}"
      else:
        echo &"{prefix}{d}"
  except UsageError as e:
    stderr.write_line(p.help)
    stderr.write_line(getCurrentExceptionMsg())
    quit 1


when isMainModule:
  meandepth_main()
