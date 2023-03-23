
const python_h = "Python.h"


type
    PyObject*                                                          {.header: python_h, importc: "PyObject".} = object


var PyNoneStruct                                                       {.nodecl,           importc: "_Py_NoneStruct".}: PyObject
template PyNone*(): ptr PyObject =
    PyNoneStruct.addr

proc PyFloat_FromDouble*(dbl: float64): ptr PyObject                   {.header: python_h, importc: "PyFloat_FromDouble".}
proc PyBytes_AsStringAndSize*(cs: cstring, size: cint): ptr PyObject   {.header: python_h, importc: "PyBytes_FromStringAndSize".}
