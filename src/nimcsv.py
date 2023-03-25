import logging
from enum import Enum
from typing import NewType, Union, List, Dict, Iterator

import pynimcsv

__ALL__ = ['parse_rows']


log = logging.getLogger(__name__)
log.setLevel(logging.DEBUG)


class ValueTypeEnum(Enum):
    Skip = 0
    Text = 1
    Integer = 2
    Float = 3


FieldName = NewType('FieldName', str)
ValueType = NewType('ValueType', Union[str, int, float])
Schema = NewType('Schema', Dict[FieldName, ValueType])
Row = NewType("Row", List[Union[ValueType, None]])


def to_schema_enum(value_type: ValueType) -> int:
    if value_type is str:
        return ValueTypeEnum.Text.value
    elif value_type is int:
        return ValueTypeEnum.Integer.value
    elif value_type is float:
        return ValueTypeEnum.Float.value
    else:
        raise ValueError(f"{value_type} is not a valid ValueType.")


def to_schema_vector(header: List[str], schema: Schema) -> List[int]:
    schema_vec = []
    for i, field_name in enumerate(header):
        if field_name in schema:
            print(f"[CONV] {field_name} -> {schema[field_name].__name__}")
            schema_vec.append(to_schema_enum(schema[field_name]))
        else:
            print(f"[SKIP] {field_name} not in schema.")
            schema_vec.append(ValueTypeEnum.Skip.value)

    return schema_vec


def read_rows(filepath: str, schema: Schema, skip_header: bool = True) -> Iterator[List[Row]]:
    header = pynimcsv.read_header(filepath)
    schema_vec = to_schema_vector(header, schema)
    rows_iter = pynimcsv.read_rows(filepath, schema=schema_vec)
    if skip_header:
        next(rows_iter)

    return rows_iter
