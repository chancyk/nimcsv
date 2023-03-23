version       = "0.0.1"
author        = "Chancy Kennedy"
description   = "SIMD CSV Parser."
license       = "MIT"
srcDir        = "src"
binDir        = "bin"
bin           = @["nimcsv"]


# Dependencies
requires "nimsimd >= 1.2.5"

task prod, "compile and run release version":
    exec "nim c -r -d:release --gc:arc --passC:-IC:\\Python38\\include --passL:C:\\Python38\\python38.dll -o:./bin/nimcsv.exe src/nimcsv.nim"
