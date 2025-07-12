// Copyright (c) 2023 Christoffer Lerno. All rights reserved.
// Use of this source code is governed by the MIT license
// a copy of which can be found in the LICENSE_STDLIB file.
module json;
import std::io;
import std::collections::object;

fn Object*? parse_string(Allocator allocator, String s)
{
	return parse(allocator, (ByteReader){}.init(s));
}

fn Object*? tparse_string(String s)
{
	return parse(tmem, (ByteReader){}.init(s));
}

fn Object*? parse(Allocator allocator, InStream s)
{
	@stack_mem(512; Allocator smem)
	{
		JsonContext context = { .last_string = dstring::new_with_capacity(smem, 64), .stream = s, .allocator = allocator };
		@pool()
		{
			Object* o = parse_any(&context)!;
			defer catch o.free();
			while (char c = read_next(&context)!, c != 0)
			{
				if (c.is_space()) continue;
				return UNEXPECTED_CHARACTER?;
			}
			if (context.stream.available() ?? 0) return UNEXPECTED_CHARACTER?;
			return o;
		};
	};
}

fn Object*? tparse(InStream s)
{
	return parse(tmem, s);
}

// -- Implementation follows --

fn Object*? parse_from_token(JsonContext* context, JsonTokenType token) @local
{
	switch (token)
	{
		case NO_TOKEN: unreachable();
		case LBRACE: return parse_map(context);
		case LBRACKET: return parse_array(context);
		case COMMA:
		case RBRACE:
		case RBRACKET:
		case COLON: return UNEXPECTED_CHARACTER?;
		case STRING: return object::new_string(context.last_string.str_view(), context.allocator);
		case NUMBER: return object::new_float(context.last_number, context.allocator);
		case TRUE: return object::new_bool(true);
		case FALSE: return object::new_bool(false);
		case NULL: return object::new_null();
		case EOF: return io::EOF?;
	}
}

fn Object*? parse_any(JsonContext* context) @local
{
	return parse_from_token(context, advance(context));
}

fn Object*? parse_map(JsonContext* context) @local
{
	Object* map = object::new_obj(context.allocator);
	defer catch map.free();
	JsonTokenType token = advance(context)!;
	defer context.depth--;
	if (++context.depth >= max_depth) return json::MAX_DEPTH_REACHED?;

	@stack_mem(256; Allocator mem)
	{
		DString temp_key = dstring::new_with_capacity(mem, 32);
		while (token != JsonTokenType.RBRACE)
		{
			if (token != JsonTokenType.STRING) return UNEXPECTED_CHARACTER?;
			DString string = context.last_string;
			// Copy the key to our temp holder, since our
			// last_string may be used in parse_any
			temp_key.clear();
			temp_key.append(string);
			parse_expected(context, COLON)!;
			Object* element = parse_any(context)!;
			map.set(temp_key.str_view(), element);
			token = advance(context)!;
			if (token == JsonTokenType.COMMA)
			{
				token = advance(context)!;
				continue;
			}
			if (token != JsonTokenType.RBRACE) return UNEXPECTED_CHARACTER?;
		}
		return map;
	};
}

fn Object*? parse_array(JsonContext* context) @local
{
	Object* list = object::new_obj(context.allocator);
	defer catch list.free();
	defer context.depth--;
	if (++context.depth >= max_depth) return json::MAX_DEPTH_REACHED?;
	JsonTokenType token = advance(context)!;
	while (token != JsonTokenType.RBRACKET)
	{
		Object* element = parse_from_token(context, token)!;
		list.push(element);
		token = advance(context)!;
		if (token == JsonTokenType.COMMA)
		{
			token = advance(context)!;
			continue;
		}
		if (token != JsonTokenType.RBRACKET) return UNEXPECTED_CHARACTER?;
	}
	return list;
}
