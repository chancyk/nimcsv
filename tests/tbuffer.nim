import std/strutils
import ptr_math

type
    Buffer = ptr UncheckedArray[char]

block:
    var arr = cast[Buffer](alloc(100 * sizeof(char)))
    var f = open("./tests/sample.txt", fmRead)
    let bytes_read = readBuffer(f, arr, 100)
    echo "Unchecked Buffer:  ", arr.toOpenArray(0, 19).join("")
    assert arr.toOpenArray(0, 19) == "11111111111111111111"
    f.close()

block:
    var arr = cast[Buffer](alloc(100 * sizeof(char)))
    arr[0] = 'a'
    arr[1] = 'b'
    var f = open("./tests/sample.txt", fmRead)
    var arr_ptr = arr[0].addr + 2
    let bytes_read = readBuffer(f, arr_ptr, 98)
    echo "Unchecked Shifted: ", arr.toOpenArray(0, 19).join("")
    assert arr.toOpenArray(0, 19) == "ab111111111111111111"
