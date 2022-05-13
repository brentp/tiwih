import hts
import strformat
import strutils
import argparse

proc vcf2bedpe(ivcf:var VCF, ofh:File, drop_bnds:bool=true) =
  var svt:string
  for v in ivcf:
    svt = ""
    if v.info.get("SVTYPE", svt) == Status.OK and svt == "BND" and drop_bnds: continue
    ofh.write(&"{v.CHROM}\t{v.start}\t{v.start+1}\t{v.CHROM}\t{v.stop}\t{v.stop+1}\t{svt}\n")

  ivcf.close()
  ofh.close()

proc vcf2bedpe_main*(args:seq[string]=commandLineParams()) =

  var p = newParser("vcf2bedpe"):
    option("-o", "--output-file", help="path to output bedpe")
    arg("vcf", nargs=1, help="SV vcf")

  try:
    var opts = p.parse(args)
    if opts.help:
      quit 0
    var ivcf:VCF
    if not ivcf.open(opts.vcf, threads=1):
      quit &"[vcf2bedpe] couldn't open vcf/bcf: {opts.vcf}"

    var ofh:File
    if not ofh.open(opts.output_file, mode=fmWrite):
      quit &"[vcf2bedpe] couldn't open {opts.output_file}"

    vcf2bedpe(ivcf, ofh)
  except UsageError as e:
    stderr.write_line(p.help)
    stderr.write_line(getCurrentExceptionMsg())
    quit 1
when isMainModule:
  vcf2bedpe_main()
