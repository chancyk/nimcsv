from enum import Enum
from typing import NewType, Union, List, Dict, Iterator
from logging import getLogger

import pynimcsv

__ALL__ = ['parse_rows']


log = getLogger(__name__)


class ValueTypeEnum(Enum):
    Text = 0
    Integer = 1
    Float = 2


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
            schema_vec.append(to_schema_enum(schema[field_name]))
        else:
            log.warning(f"{field_name} was not found in the schema. Default to Text type.")
            schema_vec.append(ValueTypeEnum.Text.value)

    return schema_vec


def read_rows(filepath: str, schema: Schema) -> Iterator[List[Row]]:
    header = pynimcsv.read_header(filepath)
    print(header)
    schema_vec = to_schema_vector(header, schema)
    return pynimcsv.read_rows(filepath, schema=schema_vec)
