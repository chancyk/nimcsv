version       = "0.0.1"
author        = "Chancy Kennedy"
description   = "SIMD CSV Parser."
license       = "MIT"
srcDir        = "src"
binDir        = "bin"
bin           = @["nimcsv"]


# Dependencies
requires "nim >= 1.6.12"
requires "nimsimd >= 1.2.5"

task sample, "compile and run the sample":
    exec "nim c -r -d:release --gc:arc --passC:-IC:\\Python38\\include --passL:C:\\Python38\\python38.dll -o:./bin/nimcsv.exe src/main.nim"

task sampleprof, "compile and run the sample":
    exec "nim c -r -d:release --stackTrace:on --debugger:native --gc:arc --passC:-IC:\\Python38\\include --passL:C:\\Python38\\python38.dll -o:./bin/nimcsv.exe src/main.nim"

task test, "run tests":
    exec "nim r --gc:arc ./tests/tparse.nim"
    exec "nim r --gc:arc ./tests/tbuffer.nim"
