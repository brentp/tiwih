import hts
import strformat
import argparse

proc setref(ivcf:var VCF, ovcf:var VCF, fai:Fai, unset_id:bool) =
  ovcf.copy_header(ivcf.header)
  doAssert ovcf.write_header

  for v in ivcf:
    if v.REF in [".", "", "N"]:
      let allele = fai.get($v.CHROM, v.start.int, v.start.int)
      v.REF=allele
    if unset_id:
      v.ID = "."

    #[
    if v.REF.len > 1 or v.ALT[0].len > 1:
      var svt:string
      if v.info.get("SVTYPE", svt) != Status.OK:
        var entry:string
        if v.ALT[0].startsWith("<INS"):
          entry = "INS"
        elif v.ALT[0].startsWith("<DEL"):
          entry = "DEL"
        else:
          echo v.ALT
        echo v.info.set("SVTYPE", entry)
        ]#

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
