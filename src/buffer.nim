import std/[strformat, strutils]


const
    MIN_BUFFER_SIZE* = 256 + 32
    BUFFER_SIZE* = 65536


type
  Buffer* = ref object
    raw*: ptr UncheckedArray[char]
    capacity*: int
    size*: int


proc allocBuffer*(buffer_size: int): Buffer =
  if buffer_size < MIN_BUFFER_SIZE:
    raise newException(OverflowDefect, fmt"Buffer must be at least {MIN_BUFFER_SIZE}")
  var buffer = Buffer()
  buffer.size = 0
  buffer.capacity = buffer_size
  buffer.raw = cast[ptr UncheckedArray[char]](alloc(buffer_size * sizeof(char)))
  return buffer


proc allocBuffer*(prev_buffer: Buffer, copy_from: int, buffer_size: int): Buffer =
  var to = 0
  var buffer = allocBuffer(buffer_size)
  if copy_from < prev_buffer.size:
    let num_bytes = prev_buffer.size - copy_from
    if num_bytes < buffer.size:
        for i in copy_from ..< buffer_size:
            buffer.raw[to] = prev_buffer.raw[i]
            to += 1
        buffer.size = num_bytes
    else:
        raise newException(OverflowDefect, "Programming error. Copied bytes cannot fit in the new buffer.")
  else:
    raise newException(OverflowDefect, "Programming error. `copy_from` is greater than the size of the buffer.")

  return buffer


proc offset*(buffer: Buffer, bytes: int): ptr char =
    if bytes < buffer.capacity:
        return buffer.raw[bytes].addr
    else:
        raise newException(OverflowDefect, "Programming error. `bytes` is larger than the capacity of the buffer.")


template free_space*(buffer: Buffer): int =
    buffer.capacity - buffer.size


proc readIntoBuffer*(file: File, buffer: Buffer, offset_bytes: int): uint32 =
  if offset_bytes < buffer.capacity:
    let offset_ptr = buffer.offset(offset_bytes)
    let buffer_size = buffer.capacity - offset_bytes
    let bytes_read = cast[uint32](readBuffer(file, offset_ptr, buffer_size))
    buffer.size += bytes_read.int
    result = bytes_read
  else:
    raise newException(OverflowDefect, "Programming error. `offset_bytes` is larger than the buffer capacity.")


proc readIntoBuffer*(file: File, buffer: Buffer): uint32 {.inline.} =
  return readIntoBuffer(file, buffer, 0)


proc toString*(buffer: Buffer, first: int, last: int): string =
    return buffer.raw.toOpenArray(first, last).join("")


proc add*(buffer: var Buffer, text: string) =
    ## Fill the buffer with a string
    if (buffer.size + text.len) > buffer.capacity:
        raise newException(OverflowDefect, "`text` will not fit in the buffer.")

    var idx = buffer.size
    for i, c in text:
        buffer.raw[idx + i] = c

    buffer.size += text.len
