import std/strutils

import ../src/buffer


type
    Array = ptr UncheckedArray[char]

block:
    ## Test a regular read into an UncheckedArray
    var arr = cast[Array](alloc(100 * sizeof(char)))
    var f = open("./tests/sample.txt", fmRead)
    let bytes_read = readBuffer(f, arr, 100)
    echo "Unchecked Buffer:  ", arr.toOpenArray(0, 19).join("")
    assert arr.toOpenArray(0, 19) == "11111111111111111111"
    f.close()

block:
    ## Read into an offset with the UncheckedArray
    var arr = cast[Array](alloc(100 * sizeof(char)))
    arr[0] = 'a'
    arr[1] = 'b'
    var f = open("./tests/sample.txt", fmRead)
    var arr_ptr = arr[2].addr
    let bytes_read = readBuffer(f, arr_ptr, 98)
    echo "Unchecked Shifted: ", arr.toOpenArray(0, 19).join("")
    assert arr.toOpenArray(0, 19) == "ab111111111111111111"
    f.close()

block:
    ## Test the Buffer API
    var buffer = allocBuffer(300)
    var f = open("./tests/sample.txt", fmRead)
    var first_bytes_read = f.readIntoBuffer(buffer)
    echo "Total Bytes: ", first_bytes_read
    assert first_bytes_read == 126
    f.setFilePos(0)
    buffer.raw[0] = 'a'
    buffer.raw[1] = 'b'
    var second_bytes_read = f.readIntoBuffer(buffer, 2)
    echo "Offset Bytes: ", second_bytes_read
    assert second_bytes_read == first_bytes_read
    assert buffer.raw[0] == 'a'
    assert buffer.raw[1] == 'b'
