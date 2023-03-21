{.experimental: "views".}

import std/[times, monotimes, strformat, strutils]
from std/unicode import reversed

import nimsimd/[avx2, pclmulqdq]
from nimsimd/avx import M256i

from python import PyObject, PyBytes_AsStringAndSize


when defined(gcc) or defined(clang):
  {.localPassc: "-mavx2 -mpclmul".}


func builtin_popcountll(x: uint64): uint32 {.importc: "__builtin_popcountll", nodecl.}
proc builtin_ctzll(x: uint64): uint32 {.importc: "__builtin_ctzll", cdecl.}


const
  DEBUG = false
  DEBUG_SEP_PARSER = false
  BUFFER_SIZE* = 65536


type
  Buffer* = ptr UncheckedArray[char]
  ParseContext* = ref object
    active_buffer_idx: int
    buffers: seq[Buffer]

  Row* = ref object
    fields: seq[PyObject]
    field_count: uint16
    next_start: int32
    next_end: int
    last_line: bool

  SIMD_Input* = ref object
    lo*: M256i
    hi*: M256i


template active_buffer(ctx: ParseContext): Buffer =
  ctx.buffers[ctx.active_buffer_idx]


##  Hamming
proc hamming*(input_num: uint64): uint32 {.inline.} =
  ##  Count the number of set bits in an unsigned integer.
  # TODO: need popcnt for other compilers
  return builtin_popcountll(input_num)


proc count_trailing_zeroes*(input_num: uint64): uint32 {.inline.} =
  ##  Count the number of zeroes following the last set bit.
  return builtin_ctzll(input_num)


proc print_text(buffer: var seq[char], i: uint32) =
  echo "Text: ", cast[seq[char]](buffer[i ..< i+64]).join("")


proc print_bits(label: string, x: uint64) =
  var bits = fmt"{x:064b}".reversed()
  echo label, bits


proc print_bits(label: string, x: int64) =
  print_bits(label, cast[uint64](x))


proc flatten_bits*(indexes: var seq[int32]; idx: uint32; bits: var uint64) {.inline.} =
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
      indexes.add  cast[int32](idx + count_trailing_zeroes(bits))
      bits = bits and (bits - 1)
      if bits == 0:
        break


proc cmp_mask_against_input*(input: SIMD_Input; m: uint8): int64 {.inline.} =
  let mask = mm256_set1_epi8(m)
  var cmp_res_lo = mm256_cmpeq_epi8(input.lo, mask)
  var cmp_res_hi = mm256_cmpeq_epi8(input.hi, mask)
  # lo into the low 32bits and hi into the high 32bits
  var res_lo: uint64 = cast[uint32](mm256_movemask_epi8(cmp_res_lo))
  var res_hi: uint64 = mm256_movemask_epi8(cmp_res_hi)
  var quote_bits = res_lo or (res_hi shl 32)
  return cast[int64](quote_bits)


template debug_parse_separators() =
  when DEBUG_SEP_PARSER:
    print_bits("Quot: ", quote_bits)
    print_bits("Mask: ", quote_mask)
    print_bits("Sepr: ", sep_mask)
    print_bits("Newl: ", end_mask)
    print_bits("Fld0: ", field_mask)
    echo fmt"[{idx_count}:{indexes.len}] "
    echo indexes[idx_count ..< indexes.len]
    idx_count = indexes.len


proc parse_separators*(buffer: var Buffer, bytes_read: uint32): seq[int32] =
  var input = SIMD_Input()
  var indexes = newSeq[int32]()
  var prev_iter_inside_quote: int64 = 0

  when DEBUG:
    var idx_count = 0

  if bytes_read != BUFFER_SIZE:
    # TODO: Need to make sure a tail shorter than 64 actually works.
    return indexes

  var i: uint32 = 0
  while i < bytes_read:
    input.lo = mm256_loadu_si256(buffer[i + 0].addr)
    input.hi = mm256_loadu_si256(buffer[i + 32].addr)
    when DEBUG_SEP_PARSER:
      print_text(buffer, i)

    ##  FIND QUOTES
    let quote_bits = cmp_mask_against_input(input, '"'.uint8)
    var quote_mask = mm_cvtsi128_si64(
      mm_clmulepi64_si128(
        mm_set_epi64x(0, quote_bits),
        mm_set1_epi8(0xFF), 0)
    )
    quote_mask = quote_mask xor prev_iter_inside_quote
    prev_iter_inside_quote = quote_mask shr 63
    ##  FIND COMMAS
    let sep_mask = cmp_mask_against_input(input, ','.uint8)
    ##  FIND NEWLINES
    let end_mask = cmp_mask_against_input(input, uint8(0x0a))
    ## Separators that are not quoted.
    var field_mask = cast[uint64]((end_mask or sep_mask) and not quote_mask)

    flatten_bits(indexes, i, field_mask)
    debug_parse_separators()
    inc(i, 64)

  return indexes


template debug_parse_row() =
  when DEBUG:
    echo "Start: ", field_start
    echo "  End: ", field_end
    echo " Char: ", c


proc parse_row(buffer: var Buffer, indexes: seq[int32], line_field_start: int32, end_idx: int): Row =
  var
    row = Row(fields: @[])
    end_of_line = false
    field_start = line_field_start

  for i in end_idx ..< indexes.len:
    let sep_idx = indexes[i]
    let c = buffer[sep_idx]
      # echo "Field: ", buffer[field_start .. sep_idx - 1]
    if c == '\n':
      end_of_line = true
    buffer[sep_idx] = '\0'
    let field_end = sep_idx - 1
    debug_parse_row()
    if field_end < field_start:
      row.fields.add  nil
    else:
      row.fields.add  py.PyBytes_AsStringAndSize(cast[cstring](buffer[field_start].addr), cint(sep_idx - field_start))

    row.field_count += 1
    field_start = sep_idx + 1

    if end_of_line:
      if i + 1 == indexes.len:
        row.next_start = 0
        row.next_end = 0
        row.last_line = true
      else:
        row.next_start = sep_idx + 1
        row.next_end = i + 1
        row.last_line = false
      return row

  row.next_start = 0
  row.last_line = true
  return row


proc readBuffer(ctx: var ParseContext, f: File): uint32 =
  var buffer = cast[Buffer](alloc(BUFFER_SIZE * sizeof(char)))
  ctx.buffers.add(buffer)
  ctx.active_buffer_idx += 1
  let bytes_read = cast[uint32](readBuffer(f, ctx.active_buffer, BUFFER_SIZE))
  return bytes_read


proc main*() =
  let t0 = getMonoTime()
  let filepath = r"C:\Temp\\EOM_OnelineLarge\\EOM_Historical.csv"
  var f = open(filepath, fmRead)
  if f == nil:
    quit(1)

  var
    buffer: Buffer
    row_count = 0
    buffer_count = 0
    row_start_idx: uint32 = 0
    bytes_read: uint32 = 0
    rows = newSeq[Row]()
    ctx = ParseContext(
      active_buffer_idx: -1,
      buffers: @[]
    )
    last_row = Row(
      fields: @[],
      next_start: 0,
      next_end: 0
    )

  bytes_read = ctx.readBuffer(f)
  while bytes_read > 0:
    buffer_count += 1
    buffer = ctx.active_buffer()
    let indexes = parse_separators(buffer, bytes_read)
    while true:
      row_count += 1
      let row = parse_row(buffer, indexes, last_row.next_start, last_row.next_end)
      last_row = row
      rows.add(row)
      if row.last_line:
        break

    bytes_read = ctx.readBuffer(f)
    if buffer_count mod 1000 == 0:
      let t1 = getMonotime()
      echo "Buffer: ", buffer_count
      echo "Elapsed: ", (t1 - t0).inMilliseconds.float64 / 1000.0

  let t2 = getMonoTime()
  var time_in_seconds = (t2 - t0).inMilliseconds.float64 / 1000.0
  echo "Elapsed: ", time_in_seconds, "s"
  echo " # Rows: ", row_count
  echo " # Buffers: ", buffer_count

main()
