v0.1.3
======
+ svsetalt: update for jasmine peculiarities

v0.1.2
======
+ meandepth: fix so that we don't need read sequence to count read-length.
  (just use cigar).

v0.1.1
======
+ new tool: slivar_jigv_tsv: writes an html page with a table of all variants
  where row-click loads and igv.js plots the appropirate data.

v0.1.0
======
+ `sum_slivar_counts` bugfix

v0.0.9
======
+ new tool: `slivar_jigv_links`: add jigv links to the tsv

v0.0.8
======
+ new tool: `slivar_split_fam`: split joint slivar files by family and inheritance mode

v0.0.7
======
+ new tool: `sum_slivar_counts`: adds the slivar variant counts in case of parallelization across regions.

v0.0.6
======
+ [combine_slivar_counts]: handles cases where we got family-based counts (with zeros) in one file that are missing in the 
  compound-het file. also allows dropping files with zero samples.

v0.0.5
======
+ new tool: `combine_slivar_counts` for combining the variant counts output by slivar from compound het and standard run.

v0.0.4
======
+ [samplename] fix for multiple with same SM tag
+ new tools: svsetalt for manta->paragraph genotyping
