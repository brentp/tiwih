import hts
import strformat
import strutils
import argparse

proc setsvalt(ivcf:var VCF, ovcf:var VCF, drop_bnds:bool) =
  ovcf.copy_header(ivcf.header)
  doAssert ovcf.write_header

  var svt:string
  var left:string
  var right:string
  for v in ivcf:
    if drop_bnds and v.info.get("SVTYPE", svt) == Status.OK and svt == "BND": continue
    if v.ALT[0] != "<INS>":
      doAssert ovcf.write_variant(v)
      continue

    if v.info.get("LEFT_SVINSSEQ", left) == Status.OK and v.info.get("RIGHT_SVINSSEQ", right) == Status.OK:
       v.ALT = v.REF & left & repeat('N', 200) & right
    elif v.info.get("SVINSSEQ", left) == Status.OK:
      v.ALT = v.REF & left
    else:
      stderr.write_line v.tostring
      stderr.write_line &"[setalt] didn't get left and right seqs for missing INS"
    doAssert ovcf.write_variant(v)

  ovcf.close()
  ivcf.close()

proc setsvalt_main*(args:seq[string]=commandLineParams()) =

  var p = newParser("setsvalt"):
    option("-o", "--output-vcf", help="path to output vcf/bcf")
    flag("--drop-bnds", help="drop any BND variants from the output")
    arg("vcf", nargs=1, help="vcf for which to set N to the proper reference allele")

  try:
    var opts = p.parse(args)
    if opts.help:
      quit 0
    var ivcf:VCF
    if not ivcf.open(opts.vcf, threads=1):
      quit &"[setref] couldn't open vcf/bcf: {opts.vcf}"

    var ovcf:VCF
    if not ovcf.open(opts.output_vcf, threads=1, mode="w"):
      quit &"[setref] couldn't open vcf/bcf: {opts.output_vcf}"

    setsvalt(ivcf, ovcf, opts.drop_bnds)
  except UsageError as e:
    stderr.write_line(p.help)
    stderr.write_line(getCurrentExceptionMsg())
    quit 1
when isMainModule:
  setsvalt_main()
