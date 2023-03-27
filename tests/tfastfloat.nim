import std/strutils

import ../src/fastfloat


block:
    var text = newSeq[char]()
    text.add '0'
    text.add '.'
    text.add '1'
    text.add '2'
    text.add '5'
    text.add '\0'

    let first = cast[cstring](text[0].addr)
    let last = cast[cstring](text[^1].addr)

    var floatNumber: float64
    let error = from_chars(first, last, floatNumber)
    echo "Input: ", text.join("")
    echo "Error: ", cast[uint8](error.ec)
    echo "Result: ", floatNumber

block:
    var text = newSeq[char]()
    text.add 'z'
    text.add 'x'
    text.add 'y'
    text.add 'w'
    text.add '\0'

    let first = cast[cstring](text[0].addr)
    let last = cast[cstring](text[^1].addr)

    var floatNumber: float64
    let error = from_chars(first, last, floatNumber)
    echo "Input: ", text.join("")
    echo "Error: ", cast[uint8](error.ec)
    echo "Result: ", floatNumber


block:
    var text = newSeq[char]()
    text.add '1'
    text.add '\0'

    let first = cast[cstring](text[0].addr)
    let last = cast[cstring](text[^1].addr)

    var floatNumber: float64
    let error = from_chars(first, last, floatNumber)
    echo "Input: ", text.join("")
    echo "Error: ", cast[uint8](error.ec)
    echo "Result: ", floatNumber
