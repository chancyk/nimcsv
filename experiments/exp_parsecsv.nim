import std/parsecsv
import std/times, std/monotimes
from std/streams import newFileStream
import nimsimd/avx

var count = 0
var csv_path = r"C:\Temp\EOM_OnelineLarge\EOM_Historical.csv"
var s = newFileStream(csv_path, fmRead)

let t0 = getMonoTime()
var parser: CsvParser
open(parser, s, csv_path)
while readRow(parser):
    count += 1
let t1 = getMonoTime()
echo "Count: ", count
echo "Elapsed: ", (t1 - t0).inMilliseconds.float64 / 1_000.0
