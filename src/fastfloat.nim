const
    fastfloat = "fast_float.h"


type
  CharsFormatEnum* = enum
    Scientific = 1,
    Fixed = 4,
    General = 5,  # Fixed | Scientific
    Hex = 8

  Errc*              {.importcpp: "std::errc", header: "<system_error>".} = enum
    invalid_argument = 29
  CharsFormat*       {.importcpp: "fast_float::chars_format", header: fastfloat.} = object
  FromCharsResult*   {.importcpp: "fast_float::from_chars_result", header: fastfloat.} = object
    ec*: Errc


proc from_chars*[T](first: cstring; last: cstring; value: var T): FromCharsResult  {.importcpp: "fast_float::from_chars(@)", raises: [], header: fastfloat.}

# template from_chars*[T](first: cstring; last: cstring; value: var T): FromCharsResult =
#     from_chars(first, last, value, cast[CharsFormat](Fixed))

template NoError*(): Errc =
    cast[Errc](0)
