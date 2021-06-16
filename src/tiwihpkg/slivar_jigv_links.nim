import os
import argparse
import hts/files
import strutils
import strformat

type cols = object
  family_id: int
  mode: int
  chr_pos_ref_alt: int

proc slivar_jigv_links(ftsv:string, dir:string) =
  var i = 0
  var header:seq[string]
  var c : cols
  for l in ftsv.hts_lines:
    var l = l
    var toks = l.strip(chars={'#'}).split("\t")
    if i == 0:
      i += 1
      var header = toks
      stderr.write_line $header
      c.family_id = header.find("family_id")
      doAssert c.family_id != -1, "[tiwih] ERROR: tsv file must contain 'family_id' column header"
      c.mode = header.find("mode")
      doAssert c.mode != -1, "[tiwih] ERROR: tsv file must contain 'mode' column header"
      c.chr_pos_ref_alt =  header.find("chr:pos:ref:alt")
      doAssert c.chr_pos_ref_alt != -1, "[tiwih] ERROR: tsv file must contain 'chr:pos:ref:alt' column header"
      stdout.write_line l, "\tjigv_link"
    else:
      var mode = toks[c.mode] # drop the comphet id from the column
      if mode.startswith("slivar_comphet"):
        mode = "slivar_comphet"
      var link = &"{dir}{mode}.{toks[c.family_id]}.jigv.html#{toks[c.chr_pos_ref_alt]}"
      stdout.write_line l, "\t", link

proc slivar_jigv_links_main*(args:seq[string]=commandLineParams()) =

  var p = newParser("slivar_jigv_links"):
    option("-d", "--directory", help="directory where jigv plots reside", default="./")
    arg("tsv", nargs=1, help="slivar tsv file")

  try:
    var opts = p.parse(args)
    if opts.help:
      quit 0

    slivar_jigv_links(opts.tsv, opts.directory)

  except UsageError as e:
    stderr.write_line(p.help)
    stderr.write_line(getCurrentExceptionMsg())
    quit 1

when isMainModule:
  slivar_jigv_links_main()
