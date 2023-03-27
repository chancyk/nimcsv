import std/[times, monotimes]

import ./nimcsv
from ./buffer import BUFFER_SIZE


proc sample*() =
  let t0 = getMonoTime()
  let filepath = r"C:\\Projects\\nimcsv\\sample.csv"
  var f = open(filepath, fmRead)
  if f == nil:
    quit(1)

  var
    ctx = createParseContext(f, BUFFER_SIZE, num_fields=85)

  # each buffer
  var rows = newSeq[Row]()
  var row_count = 0
  for row in ctx.parse_rows(schema=newSeq[ValueType]()):
    row_count += 1
    rows.add row
    if row_count mod 100_000 == 0:
      echo "Row #: ", row_count
      echo "Size: ", sizeof(row[2])

  let t2 = getMonoTime()
  var time_in_seconds = (t2 - t0).inMilliseconds.float64 / 1000.0
  echo "Elapsed: ", time_in_seconds, "s"
  echo " # Rows: ", row_count


sample()
