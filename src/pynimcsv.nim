import nimpy
from nimpy/py_types import PPyObject

import ./nimcsv
from ./buffer import BUFFER_SIZE
from ./python import PyBytes_AsStringAndSize


iterator read_rows(filepath: string): seq[PPyObject]  {.exportpy.} =
    var f = open(filepath, fmRead)
    if f == nil:
      quit(1)

    var
      rows = newSeq[Row]()
      ctx = createParseContext(f, BUFFER_SIZE, num_fields=85)

    for row in ctx.parse_rows():
      yield row.fields
