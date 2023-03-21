
const python_h = "Python.h"


{.localPassc: r"-IC:\Python38\include ".}


type
    PyObject*                                                          {.header: python_h, importc: "PyObject".} = object


var PyNoneStruct                                                       {.nodecl,           importc: "_Py_NoneStruct".}: PyObject
template PyNone*(): ptr PyObject =
    PyNoneStruct.addr

proc PyFloat_FromDouble*(dbl: float64): ptr PyObject                   {.header: python_h, importc: "PyFloat_FromDouble".}
proc PyBytes_AsStringAndSize*(cs: cstring, size: cint): ptr PyObject   {.header: python_h, importc: "PyBytes_FromStringAndSize".}


var cstr: cstring = "hello"
var pyobj_float = PyFloat_FromDouble(float64(1.23))
var pyobj_string = PyBytes_AsStringAndSize(cstr, 5)
if pyobj_string == PyNone:
    echo "Object is None"
else:
    echo "Object is something"
