import std/[strformat, strutils]


const
    MIN_BUFFER_SIZE* = 256
    BUFFER_SIZE* = 65536


type
  RawBuffer = ptr UncheckedArray[char]
  Buffer* = ref object
    raw*: RawBuffer
    capacity*: int
    size*: int


# proc `=destroy`*(x: var Buffer) =
#   echo "BUFFER DESTOYED"
#   if x.raw != nil:
#     dealloc(x.raw)

# proc `=copy`*(a: var Buffer; b: Buffer) =
#   raise newException(Exception, "Programming error. Buffer should not be copied.")

# proc `=sink`*(a: var Buffer; b: Buffer) =
#   echo "BUFFER SINK"
#   `=destroy`(a)
#   wasMoved(a)
#   a.size = b.size
#   a.capacity = b.capacity
#   a.raw = b.raw

proc `[]`*(x: Buffer; i: Natural): char =
  assert i < x.size
  x.raw[i]

proc `[]=`*(x: var Buffer; i: Natural; y: char) =
  assert i < x.size
  x.raw[i] = y


template len*(buffer: Buffer): int =
  buffer.size


proc allocBuffer*(buffer_size: int): Buffer =
  if buffer_size mod 64 != 0:
    raise newException(OverflowDefect, "`buffer_size` must be a multiple of 64.")
  if buffer_size < MIN_BUFFER_SIZE:
    raise newException(OverflowDefect, fmt"Buffer must be at least {MIN_BUFFER_SIZE}")

  var buffer = Buffer()
  buffer.size = 0
  buffer.capacity = buffer_size
  buffer.raw = cast[RawBuffer](alloc0(buffer_size * sizeof(char)))
  return buffer


proc allocBuffer*(prev_buffer: Buffer, copy_from: int): Buffer =
  var to = 0
  var buffer = allocBuffer(prev_buffer.capacity)
  if copy_from < prev_buffer.size:
    let num_bytes = prev_buffer.size - copy_from
    if num_bytes < buffer.capacity:
        for i in copy_from ..< prev_buffer.size:
            buffer.raw[to] = prev_buffer.raw[i]
            to += 1
        buffer.size = num_bytes
    else:
        raise newException(OverflowDefect, "Programming error. Copied bytes cannot fit in the new buffer.")
  else:
    raise newException(OverflowDefect, fmt"Programming error. copy_from <{copy_from}> is greater than the size of the buffer <{prev_buffer.size}>.")

  return buffer


proc offset*(buffer: Buffer, bytes: int): ptr char =
    if bytes < buffer.capacity:
        return buffer.raw[bytes].addr
    else:
        raise newException(OverflowDefect, "Programming error. `bytes` is larger than the capacity of the buffer.")


template free_space*(buffer: Buffer): int =
    buffer.capacity - buffer.size


proc readIntoBuffer*(file: File, buffer: var Buffer, offset_bytes: int): uint32 =
  if offset_bytes < buffer.capacity:
    let offset_ptr = buffer.offset(offset_bytes)
    let buffer_size = buffer.capacity - offset_bytes
    let bytes_read = cast[uint32](readBuffer(file, offset_ptr, buffer_size))
    buffer.size += bytes_read.int
    result = bytes_read
  else:
    raise newException(OverflowDefect, "Programming error. `offset_bytes` is larger than the buffer capacity.")


proc readIntoBuffer*(file: File, buffer: var Buffer): uint32 {.inline.} =
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
