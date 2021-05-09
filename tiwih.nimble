
import os
template thisModuleFile: string = instantiationInfo(fullPaths = true).filename

when fileExists(thisModuleFile.parentDir / "src/tiwih.nim"):
  # In the git repository the Nimble sources are in a ``src`` directory.
  import src/tiwihpkg/version as _
else:
  # When the package is installed, the ``src`` directory disappears.
  import tiwihpkg/version as _

# Package

version       = tiwihVersion
author        = "Brent Pedersen"
description   = "miscellaneous little (T)ools (I) (W)ished (I) (H)ad for genomes"
license       = "MIT"


# Dependencies
requires "hts >= 0.3.4", "lapper >= 0.1.6", "https://github.com/brentp/pedfile >= 0.0.3"
requires "argparse == 0.10.1"
srcDir = "src"
installExt = @["nim"]

bin = @["bptools"]

skipDirs = @["tests"]

import ospaths,strutils

task test, "run the tests":
  exec "nim c  -d:useSysAssert -d:useGcAssert --lineDir:on --debuginfo --lineDir:on --debuginfo -r --threads:on src/tiwih.nim"

