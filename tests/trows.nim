import std/[strformat, strutils]
from std/unicode import reversed

import ../src/nimcsv


proc to_bits(x: uint64): string =
    return fmt"{x:064b}".reversed()

proc string_to_bits(x: string): uint64 =
    cast[uint64](x.reversed.parseBinInt())


var f = open("./tests/quotewrap.csv", fmRead)
var ctx = createParseContext(f, 256)
var expected = @[
    @["aaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"],
    @["bbbbbbbbbbbbbbbbbbbbbbb", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"],
    @["ccccccccccccccccccccccc", "ccccccccccccccccccccccccccccccccccccccc"],
    @["dddddddddddddddddddddddddddddddddddddddddddddddddddddddddd", "\"quo\nted        , text     \"", "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"],
    @["fffffffffffffffffffffff", "fffffffffffffffffffffffffffffffffffffff"]
]
var row_idx = 0
for row in ctx.parse_rows():
    echo fmt"Row [{row_idx}]: ", row.fields.join(", ").replace("\n", "|")
    for field_idx, field in row.fields:
        let expect = expected[row_idx][field_idx]
        assert $field == expect, fmt"{field} does not match {expect}"
    row_idx += 1
