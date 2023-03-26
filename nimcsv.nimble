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
# requires "nimpy >= 0.2.0"

task sample, "compile and run the sample":
    # --passC:-IC:\\Python38\\include --passL:C:\\Python38\\python38.dll
    exec "nim cpp -r -d:release --mm:arc -o:./bin/nimcsv.exe src/main.nim"

task sampleprof, "compile and run the sample":
    exec "nim c -r -d:release --threads:on --stackTrace:on --debugger:native --mm:arc -o:./bin/nimcsv.exe src/main.nim"

task debug, "compile with debug flags":
    exec "nim c -r --stackTrace:on --debugger:native --mm:arc -o:./bin/nimcsv.exe ./src/main.nim"

task pymod, "build the nimpy python module":
    exec "nim c -d:release --stackTrace:on --debugger:native -d:exportpymod --app:lib --out:./bin/pynimcsv.pyd --threads:on --tlsEmulation:off --passL:-static --mm:arc ./src/pynimcsv.nim"

task vtunepy, "build pymod and run vtune":
    # generates a vtune_report directory
    exec "nim c -d:release -d:exportpymod --stackTrace:on --debugger:native --app:lib --out:./bin/pynimcsv.pyd --threads:on --tlsEmulation:off --passL:-static --gc:arc ./src/pynimcsv.nim"
    exec "vtune -collect hotspots -knob sampling-mode=hw -knob enable-stack-collection=true --app-working-dir=C:\\Projects\\nimcsv -r vtune_report -- C:\\Python38\\python.exe C:\\Projects\\nimcsv\\tests\\test_read_rows.py"

task test, "run tests":
    exec "nim r --gc:arc --verbosity:0 --hints:off ./tests/tparse.nim"
    exec "nim r --gc:arc --verbosity:0 --hints:off ./tests/tbuffer.nim"
    exec "nim r --gc:arc --verbosity:0 --hints:off ./tests/trows.nim"
    exec "nim r --gc:arc --verbosity:0 --hints:off --passC:-IC:\\Projects\\nimcsv\\src ./tests/tfastfloat.nim"
