import hts
import hts/files
import strformat
import tables
import pedfile
import strutils
import argparse
import ./samplename

proc pedbam(samples:var seq[Sample], bam_list:string, drop_samples_without_bam:bool) =

  var t = newTable[string, Sample]()
  for s in samples:
    t[s.id] = s

  echo &"#family_id\tsample_id\tpaternal_id\tsex\tphenotype\tpath"
  for l in bam_list.hts_lines:
    var ibam:Bam
    if not ibam.open(l):
      quit &"[tiwih pedbam] couldn't open alignment file: {l}"
    var bam_samples = ibam.samplename()
    doAssert bam_samples.len == 1, &"[tiwih pedbam] found {bam_samples} sample names (SM read-group tags in bam header), expected exactly one."
    if bam_samples[0] notin t:
      stderr.write_line &"[tiwih pedbam] WARNING: {bam_samples[0]} not found in pedigree file"
    t[bam_samples[0]].extra.add(Pair(key: "bam_path", val: l))
    ibam.close()

  for s in samples:
    var path: string
    try:
      path = s["bam_path"]
    except:
      stderr.write_line &"[tiwih pedbam] WARNING: sample in pedigree file: {s.id} not found list of alignment files"
      if drop_samples_without_bam:
        continue
      path = ""

    echo &"{s.family_id}\t{s.id}\t{s.paternal_id}\t{s.maternal_id}\t{s.sex}\t{s.phenotype}\t{path}"

proc pedbam_main*(args:seq[string]=commandLineParams()) =

  var p = newParser("pedbam"):
    flag("-d", "--drop-samples-without-bam", help="if the bam file for a sample in the pedigree is not found, dont output that line")
    arg("ped", nargs=1, help="pedigree/fam file (tab-delimited)")
    arg("bam_list", nargs=1, help="text file containing path to bam/cram files (1 per line)")

  try:
    var opts = p.parse(args)
    if opts.help:
      quit 0

    var samples = parse_ped(opts.ped)

    pedbam(samples, opts.bam_list, opts.drop_samples_without_bam)
  except UsageError as e:
    stderr.write_line(p.help)
    stderr.write_line(getCurrentExceptionMsg())
    quit 1

when isMainModule:
  pedbam_main()
