// Copyright (c) 2024 C3 Community. All rights reserved.
// Use of this source code is governed by the MIT license
// a copy of which can be found in the LICENSE_STDLIB file.

<*
 Unmarshal json string to target type.
*>
module json;
import std::io;
import std::collections::list;

faultdef TYPE_MISMATCH;

<*
 * Unmarshal JSON string to target type.
 * @param $TargetType: The target type to unmarshal to
 * @param json_string: The JSON string to parse and unmarshal
 * @param allocator: The allocator to use for parsing
 * @return The unmarshaled value
*>
macro unmarshal($TargetType, String json_string, Allocator allocator)
{
    @stack_mem(512; Allocator smem)
    {
        JsonContext context = {
            .last_string = dstring::new_with_capacity(smem, 64),
            .stream = (ByteReader){}.init(json_string),
            .allocator = allocator
        };

        $TargetType result = direct_parse_value($TargetType, &context)!;

        // Verify no trailing content
        while (char c = read_next(&context)!, c != 0)
        {
            if (c.is_space()) continue;
            return UNEXPECTED_CHARACTER?;
        }
        if (context.stream.available() ?? 0) return UNEXPECTED_CHARACTER?;

        return result;
    };
}

// -- Direct parsing implementation using existing tokenizer --

<*
 * Parse a JSON value directly into the target type
 * @param $TargetType: The target type to parse into
 * @param context: The parsing context
 * @return The parsed value
*>
macro direct_parse_value($TargetType, JsonContext* context)
{
    JsonTokenType token = advance(context)!;
    return parse_value_from_token($TargetType, context, token);
}

<*
 * Parse a JSON value from a token directly into the target type
 * @param $TargetType: The target type to parse into
 * @param context: The parsing context
 * @param token: The current token
 * @return The parsed value
*>
macro parse_value_from_token($TargetType, JsonContext* context, JsonTokenType token)
{
    $switch $TargetType.kindof:
        $case SIGNED_INT:
            if (token != JsonTokenType.NUMBER) return TYPE_MISMATCH?;
            return ($TargetType)context.last_number;
        $case UNSIGNED_INT:
            if (token != JsonTokenType.NUMBER) return TYPE_MISMATCH?;
            return ($TargetType)context.last_number;
        $case FLOAT:
            if (token != JsonTokenType.NUMBER) return TYPE_MISMATCH?;
            return ($TargetType)context.last_number;
        $case BOOL:
            switch (token)
            {
                case JsonTokenType.TRUE: return true;
                case JsonTokenType.FALSE: return false;
                default: return TYPE_MISMATCH?;
            }
        $case ENUM:
            if (token != JsonTokenType.STRING) return TYPE_MISMATCH?;
            return unmarshal_enum($TargetType, context.last_string.str_view())!;
        $case STRUCT:
            if (token != JsonTokenType.LBRACE) return TYPE_MISMATCH?;
            return direct_parse_struct($TargetType, context)!;
        $case ARRAY:
        $case SLICE:
            if (token != JsonTokenType.LBRACKET) return TYPE_MISMATCH?;
            return direct_parse_array($TargetType, context)!;
        $default:
            $if $TargetType.typeid == String.typeid:
                if (token != JsonTokenType.STRING) return TYPE_MISMATCH?;
                return context.last_string.str_view().tcopy();
            $else
                return TYPE_MISMATCH?;
            $endif
    $endswitch
}

<*
 * Parse a JSON object directly into a struct
 * @param $StructType: The struct type to parse into
 * @param context: The parsing context
 * @return The parsed struct value
*>
macro direct_parse_struct($StructType, JsonContext* context)
{
    $StructType result;
    JsonTokenType token = advance(context)!;
    defer context.depth--;
    if (++context.depth >= max_depth) return json::MAX_DEPTH_REACHED?;

    @stack_mem(256; Allocator mem)
    {
        DString temp_key = dstring::new_with_capacity(mem, 32);
        while (token != JsonTokenType.RBRACE)
        {
            if (token != JsonTokenType.STRING) return UNEXPECTED_CHARACTER?;

            // Copy the key to our temp holder
            temp_key.clear();
            temp_key.append(context.last_string);
            String field_name = temp_key.str_view();

            parse_expected(context, JsonTokenType.COLON)!;

            // Find matching struct field and parse value directly
            bool field_found = false;
            $foreach $member : $StructType.membersof:
                $if $member.nameof != "":
                    if (field_name == $member.nameof)
                    {
                        var $FieldType = $member.typeid;
                        $if $FieldType.kindof == ARRAY || $FieldType.kindof == SLICE:
                            // For arrays, we need to parse them specially
                            JsonTokenType value_token = advance(context)!;
                            if (value_token != JsonTokenType.LBRACKET) return TYPE_MISMATCH?;
                            $FieldType array_result = direct_parse_array($FieldType, context)!;
                            result.$eval($member.nameof) = array_result;
                        $else
                            // For non-arrays, use the standard parsing
                            $FieldType field_value = direct_parse_value($FieldType, context)!;
                            result.$eval($member.nameof) = field_value;
                        $endif
                        field_found = true;
                    }
                $endif
            $endforeach

            // Field not found in struct, skip the value
            if (!field_found)
            {
                skip_json_value(context)!;
            }
            token = advance(context)!;
            if (token == JsonTokenType.COMMA)
            {
                token = advance(context)!;
                continue;
            }
            if (token != JsonTokenType.RBRACE) return UNEXPECTED_CHARACTER?;
        }
        return result;
    };
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
 * Parse a JSON array directly into an array or slice
 * @param $ArrayType: The array/slice type to parse into
 * @param context: The parsing context
 * @return The parsed array/slice value
*>
macro direct_parse_array($ArrayType, JsonContext* context)
{
    var $ElementType = $ArrayType.inner;
    defer context.depth--;
    if (++context.depth >= max_depth) return json::MAX_DEPTH_REACHED?;

    // The LBRACKET token has already been consumed, start parsing elements
    JsonTokenType token = advance(context)!;

    // For slices, we need to collect elements in a dynamic way
    $if $ArrayType.kindof == SLICE:
        // Use List with context allocator for temporary allocation
        List{$ElementType} temp_list;
        temp_list.init(context.allocator);
        defer temp_list.free();

        while (token != JsonTokenType.RBRACKET)
        {
            $ElementType element = parse_value_from_token($ElementType, context, token)!;
            temp_list.push(element);

            token = advance(context)!;
            if (token == JsonTokenType.COMMA)
            {
                token = advance(context)!;
                continue;
            }
            if (token != JsonTokenType.RBRACKET) return UNEXPECTED_CHARACTER?;
        }

        // Convert List to slice using to_array
        return temp_list.to_array(context.allocator);
    $else
        // For fixed arrays
        $ArrayType result;
        usz array_len = 0;

        while (token != JsonTokenType.RBRACKET)
        {
            if (array_len >= $ArrayType.len) return TYPE_MISMATCH?; // Array too large
            result[array_len] = parse_value_from_token($ElementType, context, token)!;
            array_len++;

            token = advance(context)!;
            if (token == JsonTokenType.COMMA)
            {
                token = advance(context)!;
                continue;
            }
            if (token != JsonTokenType.RBRACKET) return UNEXPECTED_CHARACTER?;
        }
        return result;
    $endif
}

<*
 * Skip a JSON value without parsing it
 * @param context: The parsing context
*>
fn void? skip_json_value(JsonContext* context) @local
{
    JsonTokenType token = advance(context)!;
    switch (token)
    {
        case JsonTokenType.LBRACE:
            // Skip object
            defer context.depth--;
            if (++context.depth >= max_depth) return json::MAX_DEPTH_REACHED?;
            token = advance(context)!;
            while (token != JsonTokenType.RBRACE)
            {
                if (token != JsonTokenType.STRING) return UNEXPECTED_CHARACTER?;
                parse_expected(context, JsonTokenType.COLON)!;
                skip_json_value(context)!; // Recursively skip value
                token = advance(context)!;
                if (token == JsonTokenType.COMMA)
                {
                    token = advance(context)!;
                    continue;
                }
                if (token != JsonTokenType.RBRACE) return UNEXPECTED_CHARACTER?;
            }
            break;
        case JsonTokenType.LBRACKET:
            // Skip array
            defer context.depth--;
            if (++context.depth >= max_depth) return json::MAX_DEPTH_REACHED?;
            token = advance(context)!;
            while (token != JsonTokenType.RBRACKET)
            {
                skip_json_value_from_token(context, token)!; // Skip element with current token
                token = advance(context)!;
                if (token == JsonTokenType.COMMA)
                {
                    token = advance(context)!;
                    continue;
                }
                if (token != JsonTokenType.RBRACKET) return UNEXPECTED_CHARACTER?;
            }
            break;
        case JsonTokenType.STRING:
        case JsonTokenType.NUMBER:
        case JsonTokenType.TRUE:
        case JsonTokenType.FALSE:
        case JsonTokenType.NULL:
            // These are atomic values, nothing more to skip
            break;
        default:
            return UNEXPECTED_CHARACTER?;
    }
}

<*
 * Skip a JSON value from a given token without advancing first
 * @param context: The parsing context
 * @param token: The current token
*>
fn void? skip_json_value_from_token(JsonContext* context, JsonTokenType token) @local
{
    switch (token)
    {
        case JsonTokenType.LBRACE:
            // Skip object
            defer context.depth--;
            if (++context.depth >= max_depth) return json::MAX_DEPTH_REACHED?;
            token = advance(context)!;
            while (token != JsonTokenType.RBRACE)
            {
                if (token != JsonTokenType.STRING) return UNEXPECTED_CHARACTER?;
                parse_expected(context, JsonTokenType.COLON)!;
                skip_json_value(context)!; // Recursively skip value
                token = advance(context)!;
                if (token == JsonTokenType.COMMA)
                {
                    token = advance(context)!;
                    continue;
                }
                if (token != JsonTokenType.RBRACE) return UNEXPECTED_CHARACTER?;
            }
        case JsonTokenType.LBRACKET:
            // Skip array
            defer context.depth--;
            if (++context.depth >= max_depth) return json::MAX_DEPTH_REACHED?;
            token = advance(context)!;
            while (token != JsonTokenType.RBRACKET)
            {
                skip_json_value_from_token(context, token)!; // Skip element with current token
                token = advance(context)!;
                if (token == JsonTokenType.COMMA)
                {
                    token = advance(context)!;
                    continue;
                }
                if (token != JsonTokenType.RBRACKET) return UNEXPECTED_CHARACTER?;
            }
        case JsonTokenType.STRING:
        case JsonTokenType.NUMBER:
        case JsonTokenType.TRUE:
        case JsonTokenType.FALSE:
        case JsonTokenType.NULL:
            // These are atomic values, nothing more to skip
            break;
        default:
            return UNEXPECTED_CHARACTER?;
    }
}

