import std/[times, monotimes, strformat, strutils]
from std/unicode import reversed
from std/parseutils import parseInt, parseFloat

import nimsimd/[avx2, pclmulqdq]
from nimsimd/avx import M256i

when defined(export_pymod):
  import nimpy
  from nimpy/py_types import PPyObject
  from nimpy/py_lib import PyLib, loadPyLibFromThisProcess

import ./fastfloat
from ./buffer import allocBuffer, readIntoBuffer, Buffer, toString, BUFFER_SIZE


when defined(gcc) or defined(clang):
  {.localPassc: "-mavx2 -mpclmul".}


func builtin_popcountll(x: uint64): uint32 {.importc: "__builtin_popcountll", nodecl.}
proc builtin_ctzll(x: uint64): uint32 {.importc: "__builtin_ctzll", cdecl.}


const
  DEBUG = false
  DEBUG_SEP_PARSER = false


type
  ParseContext* = ref object
    file*: File
    buffer_size*: int
    buffers*: seq[Buffer]
    separator*: char
    quote*: char
    newline*: char
    active_buffer_idx: int
    quote_mask: int64
    prev_iter_inside_quote: int64
    num_fields: int

  SIMD_Input* = ref object
    lo*: M256i
    hi*: M256i

type
  ValueType* = enum
    Text
    Integer
    Float

when defined(export_pymod):
  type
    Row* = object
      fields*: seq[PPyObject]
      field_count*: uint16
else:
  type
    Row* = object
      fields*: seq[cstring]
      field_count*: uint16


template has_active_buffer*(ctx: ParseContext): bool =
  ctx.active_buffer_idx >= 0

template activeBuffer*(ctx: ParseContext): Buffer =
  ctx.buffers[ctx.active_buffer_idx]


##  Hamming
proc hamming*(input_num: uint64): uint32 {.inline.} =
  ##  Count the number of set bits in an unsigned integer.
  # TODO: need popcnt for other compilers
  return builtin_popcountll(input_num)


proc count_trailing_zeroes*(input_num: uint64): uint32 {.inline.} =
  ##  Count the number of zeroes following the last set bit.
  return builtin_ctzll(input_num)


proc print_text(buffer: Buffer, i: int) =
  echo "Text: ", buffer.toString(i, i + 63).replace("\n", "|")


proc print_bits(label: string, x: uint64) =
  var bits = fmt"{x:064b}".reversed()
  echo label, bits


proc print_bits(label: string, x: int64) =
  print_bits(label, cast[uint64](x))


proc flatten_bits*(indexes: var seq[int32]; idx: int; bits: var uint64) {.inline.} =
  ##  Convert a bit mask to the integer indexes of each set bit:
  ##
  ##    00100100 -> [5, 2]
  ##
  ##  This uses a trick of subtracting 1 from the number, which will convert
  ##  all of the bits before the least set bit to 1's, which can then be used
  ##  to mask off that portion:
  ##
  ##    00100100 - 1 == 00100011
  ##
  ##    00100100 & 00100011 == 00100000
  ##                              ^^^^^
  ##                              count
  ##
  ##  The trailing zeroes are then counted, as above, to get the index position.
  if bits != 0:
    while true:
      indexes.add  cast[int32](idx.uint32 + count_trailing_zeroes(bits))
      bits = bits and (bits - 1)
      if bits == 0:
        break


proc cmp_mask_against_input*(input: SIMD_Input; m: uint8): int64 {.inline.} =
  let mask = mm256_set1_epi8(m)
  var cmp_res_lo = mm256_cmpeq_epi8(input.lo, mask)
  var cmp_res_hi = mm256_cmpeq_epi8(input.hi, mask)
  # lo into the low 32bits and hi into the high 32bits
  var res_lo: uint64 = cast[uint32](mm256_movemask_epi8(cmp_res_lo))
  var res_hi: uint64 = cast[uint32](mm256_movemask_epi8(cmp_res_hi))
  var quote_bits = res_lo or (res_hi shl 32)
  return cast[int64](quote_bits)


template debug_parse_separators() =
  when DEBUG_SEP_PARSER:
    print_bits("Quot: ", quote_bits)
    print_bits("Mask: ", quote_mask)
    print_bits("Sepr: ", sep_mask)
    print_bits("Newl: ", end_mask)
    print_bits("Fld0: ", field_mask)
    # echo fmt"[{idx_count}:{indexes.len}] "
    # echo indexes[idx_count ..< indexes.len]
    idx_count = indexes.len


proc parse_separators*(ctx: var ParseContext): seq[int32] =
  var input = SIMD_Input()
  var indexes = newSeqOfCap[int32](int(ctx.buffer_size / 4))
  var idx_count = 0

  let buffer = ctx.active_buffer()

  var i = 0
  while i < buffer.size:
    input.lo = mm256_loadu_si256(buffer.raw[i +  0].addr)
    input.hi = mm256_loadu_si256(buffer.raw[i + 32].addr)
    when DEBUG_SEP_PARSER:
      print_text(buffer, i)

    ##  FIND QUOTES
    let quote_bits = cmp_mask_against_input(input, ctx.quote.uint8)
    var quote_mask = mm_cvtsi128_si64(
      mm_clmulepi64_si128(
        mm_set_epi64x(0, quote_bits),
        mm_set1_epi8(0xFF), 0)
    )
    quote_mask = quote_mask xor ctx.prev_iter_inside_quote
    ctx.quote_mask = quote_mask
    ctx.prev_iter_inside_quote = ctx.quote_mask shr 63
    ##  FIND COMMAS
    let sep_mask = cmp_mask_against_input(input, ctx.separator.uint8)
    ##  FIND NEWLINES
    let end_mask = cmp_mask_against_input(input, ctx.newline.uint8)
    ## Separators that are not quoted.
    var field_mask = cast[uint64]((end_mask or sep_mask) and not quote_mask)

    debug_parse_separators()
    flatten_bits(indexes, i, field_mask)
    inc(i, 64)

  return indexes


template debug_parse_row() =
  when DEBUG:
    echo "Row #: ", row_count
    echo "Start: ", field_start
    echo "  End: ", field_end
    echo " Char: ", c


proc addBuffer*(ctx: var ParseContext, buffer: Buffer) =
  ctx.active_buffer_idx += 1
  ctx.buffers.add(buffer)


proc readBuffer*(ctx: var ParseContext, prev_buffer: Buffer, start_index: int): uint32 =
  var buffer = allocBuffer(prev_buffer, start_index)
  let num_bytes = readIntoBuffer(ctx.file, buffer, ctx.buffer_size - start_index)
  ctx.addBuffer(buffer)
  return num_bytes


proc readBuffer*(ctx: var ParseContext): uint32 =
  var buffer = allocBuffer(ctx.buffer_size)
  let num_bytes = readIntoBuffer(ctx.file, buffer)
  ctx.addBuffer(buffer)
  return num_bytes


when defined(export_pymod):
  proc createRow(ctx: ParseContext): Row =
    result = Row(fields: newSeqOfCap[PPyObject](ctx.num_fields))
else:
  proc createRow(ctx: ParseContext): Row =
    result = Row(fields: newSeqOfCap[cstring](ctx.num_fields))


when defined(export_pymod):
  template convertToText(buffer: var Buffer): PPyObject =
    if buffer.raw[field_start] == '"' and buffer.raw[field_end] == '"':
      buffer.raw[field_end] = '\0'
      let field_first = cast[cstring](buffer.raw[field_start + 1].addr)
      nimValueToPy(field_first)
    else:
      let field_first = cast[cstring](buffer.raw[field_start].addr)
      nimValueToPy(field_first)

  template convertToInteger(buffer: var Buffer): PPyObject =
    var integerValue: int
    if parseInt(buffer.raw.toOpenArray(field_start, field_end), integerValue) > 0:
      nimValueToPy(integerValue)
    else:
      convertToText(buffer)

  template convertToFloat(buffer: var Buffer): PPyObject =
    var floatValue: float64
    if parseFloat(buffer.raw.toOpenArray(field_start, field_end), floatValue) > 0:
      nimValueToPy(floatValue)
    else:
      convertToText(buffer)

  template convertValueDefault(buffer: var Buffer): PPyObject =
    convertToFloat(buffer)

  template convertValue(buffer: var Buffer) =
    if field_end >= field_start:
      var value: float64
      if schema.len > 0 and row.field_count.int < schema.len:
        case schema[row.field_count]:
        of ValueType.Text:
          row.fields.add  convertToText(buffer)
        of ValueType.Integer:
          row.fields.add  convertToInteger(buffer)
        of ValueType.Float:
          row.fields.add  convertToFloat(buffer)
      else:
        row.fields.add  convertValueDefault(buffer)

      row.field_count += 1

    elif not end_of_line:
      row.fields.add  nimValueToPy(nil)
      row.field_count += 1
else:
  template convertValue(buffer: Buffer) =
    if field_end >= field_start:
      row.fields.add  cast[cstring](buffer.raw[field_start].addr)
      row.field_count += 1
    elif not end_of_line:
      row.fields.add  nil
      row.field_count += 1


iterator parse_rows*(ctx: var ParseContext, schema: seq[ValueType]): Row =
  var
    row_count = 0
    buffer_count = 0
    prev_buffer: Buffer
    buffer: Buffer
    bytes_read: uint32
    indexes: seq[int32]
    row = ctx.createRow()
    end_of_line = false
    field_start: int32

  if not ctx.has_active_buffer():
    bytes_read = ctx.readBuffer()
    buffer = ctx.activeBuffer()
    indexes = ctx.parse_separators()

  while bytes_read > 0:
    for i in 0 ..< indexes.len:
      let sep_idx = indexes[i]
      let c = buffer.raw[sep_idx]
      if c == '\n':
        end_of_line = true

      buffer.raw[sep_idx] = '\0'
      let field_end = sep_idx - 1
      debug_parse_row()
      convertValue(buffer)
      field_start = sep_idx + 1

      if end_of_line:
        yield move row
        row_count += 1
        row = ctx.createRow()
        end_of_line = false

    # parse the next buffer and continue
    buffer_count += 1
    prev_buffer = buffer
    if field_start < prev_buffer.size:
      let remaining = prev_buffer.size - field_start
      ## We might be moving a quote from one buffer to another, so
      ## we need to take the state before that possible quote.
      ctx.prev_iter_inside_quote = (ctx.quote_mask shl remaining) shr 63
      bytes_read = ctx.readBuffer(prev_buffer, field_start)
      field_start = 0
    else:
      ctx.prev_iter_inside_quote = ctx.quote_mask shr 63
      bytes_read = ctx.readBuffer()
      field_start = 0

    if bytes_read == 0:
      if row.field_count > 0:
        yield move row
      break
    buffer = ctx.activeBuffer()
    indexes = ctx.parse_separators()


proc createParseContext*(
  file: File, buffer_size: int,
  separator: char = ',',
  quote: char = '"',
  newline: char = '\n',
  num_fields: int = 64
): ParseContext =
  result = ParseContext(
    file: file,
    buffer_size: buffer_size,
    active_buffer_idx: -1,
    buffers: @[],
    separator: separator,
    quote: quote,
    newline: newline,
    prev_iter_inside_quote: 0,
    num_fields: num_fields
    # py_lib: loadPyLibFromThisProcess()
  )


proc main*() =
  let t0 = getMonoTime()
  let filepath = r"C:\\Projects\\nimcsv\\sample.csv"
  var f = open(filepath, fmRead)
  if f == nil:
    quit(1)

  var
    rows = newSeq[Row]()
    ctx = createParseContext(f, BUFFER_SIZE, num_fields=85)

  # each buffer
  var row_count = 0
  for row in ctx.parse_rows(schema=newSeq[ValueType]()):
    row_count += 1
    rows.add(row)
    if row_count mod 100_000 == 0:
      echo "Row #: ", row_count

  let t2 = getMonoTime()
  var time_in_seconds = (t2 - t0).inMilliseconds.float64 / 1000.0
  echo "Elapsed: ", time_in_seconds, "s"
  echo " # Rows: ", rows.len
