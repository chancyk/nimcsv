from parseutils import parseBiggestFloat


block:
    var number = newSeq[char]()
    number.add '0'
    number.add '.'
    number.add '7'
    number.add '\0'

    let cstr = cast[cstring](number[0].addr)
    echo "[tfloat] CString: ", cstr

    var output: float64
    echo "[tfloat] OpenArray: ", cstr.toOpenArray(0, 2)
    let result = parseBiggestFloat(cstr.toOpenArray(0, 2), output)
    if result == 0:
        raise

    echo "[tfloat] Float: ", output

block:
    var output: float64
    var number2 = newSeq[char]()
    number2.add '9'
    number2.add '\0'
    let cstr2 = cast[cstring](number2[0].addr)
    echo "[tfloat] CString2: ", cstr2
    let result2 = parseBiggestFloat(cstr2.toOpenArray(0, 1), output)
    if result2 == 0:
        raise
    echo "[tfloat] Integer: ", output
