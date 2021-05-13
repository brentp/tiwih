import strformat
import strutils
import argparse
import regex

type region* = object
  chrom*: string
  start*: int
  stop*:int

proc `$`*(r:region): string =
  result = &"{r.chrom}:{r.start + 1}-{r.stop}"

iterator fairegions(fai_path:string, chromexcl:string, region_size:int): region =
  var fh:File
  if not fh.open(fai_path):
    raise newException(OSError, &"couldn't open file: {fai_path}")

  var p = re(chromexcl)

  for line in fh.lines:
    let toks = line.split('\t')
    if p in toks[0]: continue
    let chrom_len = parseInt(toks[1])

    for chrom_start in countup(0, chrom_len + 1, region_size):
      let chrom_end = min(chrom_len, chrom_start + region_size)
      yield region(chrom: toks[0], start: chrom_start, stop: chrom_end)


proc fairegions_main*(args:seq[string]=commandLineParams()) =

  var p = newParser("fairegions"):
    option("-e", "--excl", help="regex pattern of chroms to exclude", default=r"^chrEBV$|^GL|^NC|_random$|Un_|^HLA\-|_alt$|hap\d$")
    option("--region_size", help="size of region to generate", default="5000000")
    arg("fai", nargs=1, help="fai (not fasta)")

  try:
    var opts = p.parse(args)
    if opts.help:
      quit 0

    for r in fairegions(opts.fai, opts.excl, parseInt(opts.region_size)):
      echo r
  except UsageError as e:
    stderr.write_line(p.help)
    stderr.write_line(getCurrentExceptionMsg())
    quit 1


when isMainModule:
  fairegions_main()
