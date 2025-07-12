// Copyright (c) 2024 C3 Community. All rights reserved.
// Use of this source code is governed by the MIT license
// a copy of which can be found in the LICENSE_STDLIB file.

<*
 Unmarshal json string to a struct.
*>
module json;
import std::collections::object;

<*
 * Unmarshal JSON string to target type.
 * @param $TargetType: The target type to unmarshal to
 * @param json_string: The JSON string to parse and unmarshal
 * @param allocator: The allocator to use for parsing
 * @return The unmarshaled value
*>
macro unmarshal($TargetType, String json_string, Allocator allocator)
{
    Object* json_obj = parse_string(allocator, json_string)!;
    defer (void)json_obj.free();

    return convert_json_value($TargetType, json_obj, allocator);
}

<*
 * Helper macro to convert JSON Object value to the target type
 * @param [in] $TargetType The target type to convert to
 * @param [in] json_obj The JSON Object to convert from
 * @param [in] allocator The allocator for string copying
 * @return The converted value
*>
macro convert_json_value($TargetType, Object* json_obj, Allocator allocator)
{
    $switch $TargetType.kindof:
        $case SIGNED_INT:
            // JSON numbers are always floats, so allow float-to-int conversion
            if (!json_obj.is_float()) return TYPE_MISMATCH?;
            return ($TargetType)json_obj.f;
        $case UNSIGNED_INT:
            // JSON numbers are always floats, so allow float-to-int conversion
            if (!json_obj.is_float()) return TYPE_MISMATCH?;
            return ($TargetType)json_obj.f;
        $case FLOAT:
            if (!json_obj.is_float()) return TYPE_MISMATCH?;
            return ($TargetType)json_obj.f;
        $case BOOL:
            if (!json_obj.is_bool()) return TYPE_MISMATCH?;
            return json_obj.b;
        $case ENUM:
            if (!json_obj.is_string()) return TYPE_MISMATCH?;
            return unmarshal_enum($TargetType, json_obj.s)!;
        $case STRUCT:
            if (!json_obj.is_map()) return TYPE_MISMATCH?;
            return unmarshal_struct($TargetType, json_obj, allocator)!;
        $default:
            $if $TargetType.typeid == String.typeid:
                if (!json_obj.is_string()) return TYPE_MISMATCH?;
                return json_obj.s.tcopy();
            $else
                return TYPE_MISMATCH?;
            $endif
    $endswitch
}

<*
 * Unmarshal JSON Object to a struct
 * @param $StructType: The struct type to unmarshal to
 * @param json_obj: The JSON Object to unmarshal from
 * @param allocator: The allocator to use for string copying
 * @require @typekind($StructType) == STRUCT
 * @return The unmarshaled struct value
*>
macro unmarshal_struct($StructType, Object* json_obj, Allocator allocator)
{
    if (!json_obj.is_map()) return TYPE_MISMATCH?;

    $StructType result;

    $foreach $member : $StructType.membersof:
        $if $member.nameof != "":
            {
                // Get the JSON value for this field
                Object*? field_obj = json_obj.get($member.nameof);
                if (try field_obj)
                {
                	// Convert JSON value to struct field based on type
                	var $FieldType = $member.typeid;
                	$if $FieldType.kindof == ARRAY || $FieldType.kindof == SLICE:
                    	if (!field_obj.is_array()) return TYPE_MISMATCH?;
                    	$FieldType array_result = unmarshal_array($FieldType, field_obj, allocator)!;
                    	result.$eval($member.nameof) = array_result;
                	$else
                    	$FieldType converted_value = convert_json_value($FieldType, field_obj, allocator)!;
                    	result.$eval($member.nameof) = converted_value;
                	$endif
                }
                // If field not found in JSON, use default value (do nothing)
            }
        $endif
    $endforeach

    return result;
}

<*
 * Unmarshal a string to an enum value by name lookup
 * @param [in] $EnumType The enum type to unmarshal to
 * @param [in] enum_name The string name of the enum value
 * @return The enum value if found
*>
macro unmarshal_enum($EnumType, String enum_name)
{
    $foreach $i, $name : $EnumType.names:
        if (enum_name == $name)
        {
            return $EnumType.from_ordinal($i);
        }
    $endforeach
    return TYPE_MISMATCH?;
}

<*
 * Unmarshal a JSON array to an array or slice
 * @param [in] $ArrayType The array/slice type to unmarshal to
 * @param [in] json_array The JSON array Object to unmarshal from
 * @param [in] allocator The allocator to use for memory allocation
 * @return The unmarshaled array/slice value
*>
macro unmarshal_array($ArrayType, Object* json_array, Allocator allocator)
{
    var $ElementType = $ArrayType.inner;

    if (!json_array.is_array()) return TYPE_MISMATCH?;

    usz array_len = json_array.get_len();

    // Allocate result based on type
    $if $ArrayType.kindof == SLICE:
        // For slices, allocate memory using temp allocator
        $ElementType[] result = allocator::alloc_array(tmem, $ElementType, array_len);
    $else
        // For fixed arrays, check size compatibility
        if (array_len > $ArrayType.len)
        {
            return TYPE_MISMATCH?; // Array too large
        }
        $ArrayType result;
    $endif

    // Fill the array/slice with values
    for (usz i = 0; i < array_len; i++)
    {
        Object* element_obj = json_array.get_at(i);
        if (!element_obj) return TYPE_MISMATCH?;

        // Use the unified conversion helper
        $ElementType converted_value = convert_json_value($ElementType, element_obj, allocator)!;
        result[i] = converted_value;
    }

    return result;

}

