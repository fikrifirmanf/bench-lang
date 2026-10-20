# Package

version       = "0.1.0"
author        = "hanabi1224"
description   = "bencher"
license       = "MIT"
srcDir        = "."
bin           = @["app"]

# Dependencies (upstream's, plus bigints, checksums and httpbeast for the programs bench-lang enables)

requires "nim >= 2.0.0"
requires "chronos"
requires "yasync"
requires "bigints"
requires "checksums"
requires "httpbeast"
