import os
import argparse
import tables
import base64
import zippy

proc encode*(s:string): string =
  return base64.encode(zippy.compress(s))

proc slivar_jigv_tsv(html_tmpl:string, prefix:string, tsv:string) =
  var etsv = tsv.readFile.encode

  var html = html_tmpl.readFile.split("<ENCODED>")
  doAssert html.len == 2, "expected an '<ENCODED>' place-holder in the html template"
  var html0 = html[0].split("<JIGV_TMPL_PATH>")
  doAssert html0.len == 2, "expected a '<JIGV_TMPL_PATH>' place-holder in the html template"

  stdout.write html0[0]
  stdout.write "jigv_plots/${data.family_id}/${data.mode}/${data.family_id}.${data.mode}.${v}.js"
  stdout.write_line html0[1]
  stdout.write etsv
  stdout.write_line html[1]

proc slivar_jigv_tsv_main*(args:seq[string]=commandLineParams()) =

  var p = newParser("slivar_jigv_tsv"):
    option("--html-template", help="html file to file with CSV info")
    option("-p", "--prefix", help="directory prefix (as given to jigv --prefix)")
    arg("tsv", nargs=1, help="slivar summary tsv file")

  try:
    var opts = p.parse(args)
    if opts.help:
      quit 0
    if opts.html_template.len == 0 or opts.prefix.len == 0:
      raise newException(UsageError, "--html-template and --prefix are required arguments")


    slivar_jigv_tsv(opts.html_template, opts.prefix, opts.tsv)

  except UsageError as e:
    stderr.write_line(p.help)
    stderr.write_line(getCurrentExceptionMsg())
    quit 1


when isMainModule:
  slivar_jigv_tsv_main()
