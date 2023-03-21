import std/[strformat, strutils]
from std/unicode import reversed

import ../src/nimcsv
import ../src/buffer as b


proc to_bits(x: int64): string =
    return fmt"{x:064b}".reversed()


proc string_to_bits(x: string): uint64 =
    cast[uint64](x.reversed.parseBinInt())


var fields = newSeq[string]()
var buffer = b.allocBuffer(512)
buffer.add  """1123,"quoted",345|1678,"nes""t""ed quotes",901|1234,567,890|2123""".replace("|", "\n")
fields.add  """0000100000000100010000100000000000000000001000100001000100010000"""
buffer.add  """,unquoted,345|2678,some text,901|2234,567,890|3123,unquoted,345|""".replace("|", "\n")
fields.add  """1000000001000100001000000000100010000100010001000010000000010001"""
buffer.add  """3678,some text,901|3234,567,890999999999999999999999999999999999""".replace("|", "\n")
fields.add  """0000100000000010001000010001000000000000000000000000000000000000"""
buffer.add  """9999|aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|b""".replace("|", "\n")
fields.add  """0000100000000000000000000000000000000000000000000000000000000010"""
buffer.add  """bbbbbbbbbbbbbbbbbbbbbbbbbbbbb|bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb""".replace("|", "\n")
fields.add  """0000000000000000000000000000010000000000000000000000000000000000"""


block:
    echo "Chunk [  0 ..  63]: ", buffer.toString(0, 63).replace("\n", "|")
    echo "                    ", fields[0]
    echo "Chunk [ 64 .. 127]: ", buffer.toString(64, 127).replace("\n", "|")
    echo "                    ", fields[1]
    echo "Chunk [128 .. 172]: ", buffer.toString(128, 172).replace("\n", "|")
    echo "                    ", fields[2]
    echo "Chunk [173 .. 236]: ", buffer.toString(173, 236).replace("\n", "|")
    echo "                    ", fields[3]
    echo "Chunk [237 .. 300]: ", buffer.toString(128, 172).replace("\n", "|")
    echo "                    ", fields[4]
    echo "\n"

    let indexes = parse_separators(buffer)
    var expected = newSeq[int32]()

    var bits: uint64
    for i in 0 .. 4:
        var bits = string_to_bits(fields[i])
        flatten_bits(expected, i * 64, bits)

    echo " Indexes: ", indexes
    echo "Expected: ", expected
    assert indexes == expected
