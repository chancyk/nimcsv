import nimpy
from nimpy/py_types import PPyObject

import ./nimcsv
from ./buffer import BUFFER_SIZE


proc read_header*(filepath: string): seq[PPyObject] {.exportpy.} =
  var
    file = open(filepath, fmRead)
    ctx = createParseContext(file, BUFFER_SIZE)

  for row in ctx.parse_rows(schema=newSeq[ValueType]()):
    return row


iterator read_rows*(filepath: string, schema: seq[ValueType]): seq[PPyObject]  {.exportpy.} =
  var
    row_num = 0
    file = open(filepath, fmRead)
    ctx = createParseContext(file, BUFFER_SIZE, num_fields=schema.len)

  for row in ctx.parse_rows(schema=schema):
    yield row
