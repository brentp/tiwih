import hts
import strformat
import strutils
import argparse

proc setref*(v:Variant, fai:Fai) =
    if v.REF in [".", "", "N"]:
      let allele = fai.get($v.CHROM, v.start.int, v.start.int)
      v.REF= $(allele[0].toUpperAscii)

proc setref(ivcf:var VCF, ovcf:var VCF, fai:Fai, unset_id:bool) =
  ovcf.copy_header(ivcf.header)
  doAssert ovcf.write_header

  for v in ivcf:
    v.setref(fai)
    if unset_id:
      v.ID = "."

    doAssert ovcf.write_variant(v)
  ovcf.close()
  ivcf.close()

proc setref_main*(args:seq[string]=commandLineParams()) =

  var p = newParser("setref"):
    option("-o", "--output-vcf", help="path to output vcf/bcf")
    flag("-u", "--clear-id", help="clear the id field of the vcf")
    arg("vcf", nargs=1, help="vcf for which to set N to the proper reference allele")
    arg("fasta", nargs=1, help="reference fasta with index to get allele")

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

    var fai:Fai
    if not fai.open(opts.fasta):
      quit &"[setref] couldn't open fasta: {opts.fasta}"

    setref(ivcf, ovcf, fai, opts.clear_id)
  except UsageError as e:
    stderr.write_line(p.help)
    stderr.write_line(getCurrentExceptionMsg())
    quit 1


when isMainModule:
  setref_main()
