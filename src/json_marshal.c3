// Copyright (c) 2024 C3 Community. All rights reserved.
// Use of this source code is governed by the MIT license
// a copy of which can be found in the LICENSE_STDLIB file.

<*
 JSON marshaling for structs containing primitive types, enums, and nested structs.
 Supports: String, int, float, double, bool, enums (always marshaled as enum names), nested structs
*>

module json;
import std::core::string;

faultdef UNSUPPORTED_TYPE;

<*
 Marshal value to JSON.

 @param output: "The output string"
 @param value: "The value to marshal"
*>
macro void? marshal(value, DString* output)
{
    var $Type = $typeof(value);

    $switch $Type.kindof:
        $case STRUCT:
            marshal_struct(value, output)!;
        $case ARRAY:
        $case SLICE:
            marshal_array(value, output)!;
        $case SIGNED_INT:
        $case UNSIGNED_INT:
             output.append(string::tformat("%d", value));
        $case FLOAT:
             output.append(string::tformat("%g", value));
        $case BOOL:
             output.append(value ? "true" : "false");
        $case ENUM:
             output.append(marshal_enum(value)!);
        $default:
            $if $Type.typeid == String.typeid:
				output.append(value.tescape(false));
				return;
            $endif
            return UNSUPPORTED_TYPE?;
    $endswitch
}

<*
 Marshal a struct to JSON.

 @param output: "The output DString"
 @param value: "The struct value to marshal"
 @require @typekind(value) == STRUCT
*>
macro void? marshal_struct(value, DString* output)
{
    var $Type = $typeof(value);
    output.append_char('{');

    var $first = true;
    $foreach $member : $Type.membersof:
        $if $member.nameof != "":
            $if !$first:
                output.append_char(',');
            $endif
            $first = false;

            output.append_char('"');
            output.append_chars($member.nameof);
            output.append_chars(`":`);

            marshal($member.get(value), output)!;
        $endif
    $endforeach

    output.append_char('}');
}

<*
 Marshal an array of values to JSON.

 @param output: "The output string"
 @param array: "The array to marshal"
*>
macro void? marshal_array(array, DString* output) @local
{
    output.append_char('[');

    foreach (i, element : array)
    {
        if (i > 0) output.append_char(',');

        // Use common marshaling logic for each element
        marshal(element, output)!;
    }

    output.append_char(']');
}

<*
 Marshal an enum value to JSON as a quoted string.
 Always uses the enum name, regardless of associated values.

 @param enum_value: "The enum value to marshal"
 @return "The JSON string representation"
*>
macro String? marshal_enum(enum_value) @local
{
    var $Type = $typeof(enum_value);

    // Convert enum to ordinal and get the name
    usz ordinal = types::any_to_enum_ordinal(&enum_value, usz)!!;
    assert(ordinal < $Type.names.len, "Illegal enum value found, numerical value was %d.", ordinal);

    // Always use enum names for JSON marshaling
    return $Type.names[ordinal].tescape(false);
}