import pedfile
import hts/vcf
import os
import argparse
import strutils
import strformat
import tables
import sets

from hts/private/hts_concat import nil

proc slivar_split_fam(samplesByFam:TableRef[string, seq[Sample]], ftemplate:string, fields:seq[string], ivcf:VCF, outputs:var TableRef[string, VCF]) =
  var sample2Fam = newTable[string, string]()
  for f, samples in samplesByFam:
    for s in samples:
      sample2Fam[s.id] = f

  var famWritten = initHashSet[string]()
  #echo ivcf.fname, " ", sample2Fam
  if ivcf.header.add_info("slivar_comphet", ".", "String", "compound hets called by slivar. format is sample/gene/id/chrom/pos/ref/alt where id is a unique integer indicating the compound-het pair.") != Status.OK:
    stderr.write_line("[tiwih] warning: problem adding 'slivar_comphet' to header")

  var sampleStr:string
  for v in ivcf:
    for field in fields:
      if v.info.get(field, sampleStr) != Status.OK: continue
      famWritten.clear()
      for s_id in sampleStr.split(","):
        var sample_id = s_id
        if '/' in sample_id:
          sample_id = sample_id.split("/", 3)[0]
        let famid = sample2Fam[sample_id] # TODO: handle samples not in ped file?
        if famWritten.containsOrIncl(famid): continue
        let path = ftemplate % ["fam", famid, "field", field]
        if path notin outputs:
          var ovcf:VCF
          if not ovcf.open(path, mode="w"):
            quit &"[tiwih] could not open output file: {path}"
          ovcf.copy_header(ivcf.header)
          var sample_ids: seq[string]
          for si in samplesByFam[famid]: sample_ids.add(si.id)
          ovcf.set_samples(sample_ids)
          doAssert ovcf.write_header
          outputs[path] = ovcf

        var v2 = v.copy()
        v2.vcf = outputs[path]
        doAssert 0 == hts_concat.bcf_subset_format(outputs[path].header.hdr, v2.c)
        doAssert outputs[path].write_variant(v2), "[tiwih] error writing variant"


proc slivar_split_fam(pedf:string, ftemplate:string, fields:string, vcfs:seq[string]) =
  var samples = parse_ped(pedf)
  var fields = fields.split(",")
  var samplesByFam = newTable[string, seq[Sample]]()
  var outputs = newTable[string, VCF]() # family-id -> VCF

  for s in samples:
    samplesByFam.mgetOrPut(s.family_id, @[]).add(s)

  for f in vcfs:
    var ivcf:VCF
    if not ivcf.open(f, threads=2):
      quit &"[tiwih] could not open vcf: {f}"

    slivar_split_fam(samplesByFam, ftemplate, fields, ivcf, outputs)
    ivcf.close()

  for v in outputs.values:
    v.close()


proc slivar_split_fam_main*(args:seq[string]=commandLineParams()) =

  var p = newParser("slivar_split_fam"):
    option("--ped", help="path to pedigree file")
    option("--template", help="string template for naming files must contain '${fam}' and '${field}", default="${fam}.${field}.vcf.gz")
    option("--fields", help="info fields that contain lists of sample ids. specify as commad delimited list")
    arg("vcfs", nargs= -1, help="path to vcfs")

  try:
    var opts = p.parse(args)
    if opts.help:
      quit 0
    if opts.ped.len == 0 or not fileExists(opts.ped):
      raise newException(UsageError, "specify path to readable pedigree file with --ped")
    if opts.fields.len == 0:
      raise newException(UsageError, "specify comma-delimited field list with --fields")
    if opts.vcfs.len == 0:
      raise newException(UsageError, "specify one or more vcfs as arguments")

    slivar_split_fam(opts.ped, opts.`template`, opts.fields, opts.vcfs)

  except UsageError as e:
    stderr.write_line(p.help)
    stderr.write_line(getCurrentExceptionMsg())
    quit 1

when isMainModule:
  slivar_split_fam_main()
