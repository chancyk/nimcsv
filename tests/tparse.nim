import std/[strformat, strutils]
from std/unicode import reversed

import ../src/nimcsv
import ../src/buffer as b


proc to_bits(x: int64): string =
    return fmt"{x:064b}".reversed()


proc string_to_bits(x: string): uint64 =
    cast[uint64](x.reversed.parseBinInt())


var fields = newSeq[string]()
var buffer1 = b.allocBuffer(256)
var buffer2 = b.allocBuffer(256)
buffer1.add  """1123,"quoted",345|1678,"nes""t""ed quotes",901|1234,567,890|2123"""
fields.add   """0000100000000100010000100000000000000000001000100001000100010000"""
buffer1.add  """,unquoted,345|2678,some text,901|2234,567,890|3123,unquoted,345|"""
fields.add   """1000000001000100001000000000100010000100010001000010000000010001"""
buffer1.add  """3678,some text,901|3234,567,890999999999999999999999999999999999"""
fields.add   """0000100000000010001000010001000000000000000000000000000000000000"""
buffer1.add  """9999|aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"aa|b"""
fields.add   """0000100000000000000000000000000000000000000000000000000000000000"""
buffer2.add  """bbbbb"bbbbbbbbbbbbbbbbbbbbbbb|bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"""
fields.add   """0000000000000000000000000000010000000000000000000000000000000000"""
buffer2.add  """cccccccccc|ccccccccccccccccccccccccccc|cccccccccccc"ccc|ccc"cccc"""
fields.add   """0000000000100000000000000000000000000010000000000000000000000000"""


echo "Buffer1 Capacity: ", buffer1.capacity
echo "Buffer1 Size:     ", buffer1.size
echo "Buffer2 Capacity: ", buffer2.capacity
echo "Buffer2 Size:     ", buffer2.size

echo "Chunk [  0 ..  63]: ", buffer1.toString(0, 63)
echo "                    ", fields[0]
echo "Chunk [ 64 .. 127]: ", buffer1.toString(64, 127)
echo "                    ", fields[1]
echo "Chunk [128 .. 191]: ", buffer1.toString(128, 191)
echo "                    ", fields[2]
echo "Chunk [192 .. 255]: ", buffer1.toString(192, 255)
echo "                    ", fields[3]
echo "\n"
echo "Chunk [256 .. 319]: ", buffer2.toString(256, 319)
echo "                    ", fields[4]
echo "Chunk [320 .. 383]: ", buffer2.toString(320, 383)
echo "                    ", fields[5]
echo "\n"

let indexes = parse_separators(buffer1, '|')
var expected = newSeq[int32]()


var bits: uint64
for i in 0 .. 4:
    var bits = string_to_bits(fields[i])
    flatten_bits(expected, i * 64, bits)

echo " Indexes: ", indexes
echo "Expected: ", expected
assert indexes == expected
