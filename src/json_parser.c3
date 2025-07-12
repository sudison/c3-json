module json;
import std::io;

faultdef UNEXPECTED_CHARACTER, INVALID_ESCAPE_SEQUENCE, INVALID_NUMBER, MAX_DEPTH_REACHED;
int max_depth = 128;

enum JsonTokenType @private
{
	NO_TOKEN,
	LBRACE,
	LBRACKET,
	COMMA,
	COLON,
	RBRACE,
	RBRACKET,
	STRING,
	NUMBER,
	TRUE,
	FALSE,
	NULL,
	EOF,
}

struct JsonContext @private
{
	uint line;
	InStream stream;
	Allocator allocator;
	JsonTokenType token;
	DString last_string;
	double last_number;
	char current;
	int depth;
	bitstruct : char
	{
		bool skip_comments;
		bool reached_end;
		bool pushed_back;
	}
}

fn JsonTokenType? lex_number(JsonContext *context, char c) @private
{
	@stack_mem(256; Allocator mem)
	{
		DString t = dstring::new_with_capacity(mem, 32);
		bool negate = c == '-';
		if (negate)
		{
			t.append(c);
			c = read_next(context)!;
		}
		if (!c.is_digit()) return INVALID_NUMBER?;
		bool leading_zero = c == '0';
		while (c.is_digit())
		{
			t.append(c);
			c = read_next(context)!;
			if (leading_zero)
			{
				if (c.is_digit()) return INVALID_NUMBER?;
				leading_zero = false;
			}
		}
		if (c == '.')
		{
			t.append(c);
			c = read_next(context)!;
			if (!c.is_digit()) return INVALID_NUMBER?;
			while (c.is_digit())
			{
				t.append(c);
				c = read_next(context)!;
			}
		}
		if ((c | 32) == 'e')
		{
			t.append(c);
			c = read_next(context)!;
			switch (c)
			{
				case '-':
				case '+':
					t.append(c);
					c = read_next(context)!;
			}
			if (!c.is_digit()) return INVALID_NUMBER?;
			while (c.is_digit())
			{
				t.append(c);
				c = read_next(context)!;
			}
		}
		pushback(context, c);
		double? d = t.str_view().to_double() ?? INVALID_NUMBER?;
		context.last_number = d!;
		return NUMBER;
	};
}

fn void pushback(JsonContext* context, char c) @private
{
	if (!context.reached_end)
	{
		assert(!context.pushed_back);
		context.pushed_back = true;
		context.current = c;
	}
}

fn char? read_next(JsonContext* context) @private
{
	if (context.reached_end) return '\0';
	if (context.pushed_back)
	{
		context.pushed_back = false;
		return context.current;
	}
	char? c = context.stream.read_byte();
	if (catch err = c)
	{
		if (err == io::EOF)
		{
			context.reached_end = true;
			return '\0';
		}
		return err?;
	}
	if (c == 0)
	{
		return UNEXPECTED_CHARACTER?;
	}
	return c;
}

fn JsonTokenType? advance(JsonContext* context) @private
{
	char c;
	// Skip whitespace
	while WS: (c = read_next(context)!)
	{
		switch (c)
		{
			case '\n':
				context.line++;
				nextcase;
			case ' ':
			case '\t':
			case '\r':
			case '\v':
				continue;
			case '/':
				if (!context.skip_comments) break WS;
				c = read_next(context)!;
				if (c != '*')
				{
					pushback(context, c);
					break WS;
				}
				while COMMENT: (true)
				{
					// Skip to */
					while (c = read_next(context)!)
					{
						if (c == '\n') context.line++;
						if (c != '*') continue;
						// Skip through all the '*'
						while (c = read_next(context)!)
						{
							if (c == '\n') context.line++;
							if (c != '*') break;
						}
						if (c == '/') break COMMENT;
					}
				}
				continue;
			default:
				break WS;
		}
	}
	switch (c)
	{
		case '\0':
			return io::EOF?;
		case '{':
			return LBRACE;
		case '}':
			return RBRACE;
		case '[':
			return LBRACKET;
		case ']':
			return RBRACKET;
		case ':':
			return COLON;
		case ',':
			return COMMA;
		case '"':
			return lex_string(context);
		case '-':
		case '0'..'9':
			return lex_number(context, c);
		case 't':
			match(context, "rue")!;
			return TRUE;
		case 'f':
			match(context, "alse")!;
			return FALSE;
		case 'n':
			match(context, "ull")!;
			return NULL;
		default:
			return UNEXPECTED_CHARACTER?;
	}
}

fn void? match(JsonContext* context, String str) @private
{
	foreach (c : str)
	{
		char l = read_next(context)!;
		if (l != c) return UNEXPECTED_CHARACTER?;
	}
}

fn void? parse_expected(JsonContext* context, JsonTokenType token) @private
{
	if (advance(context)! != token) return UNEXPECTED_CHARACTER?;
}

fn JsonTokenType? lex_string(JsonContext* context) @private
{
	context.last_string.clear();
	while LOOP: (true)
	{
		char c = read_next(context)!;
		switch (c)
		{
			case '\0':
				return io::EOF?;
			case 1..31:
				return UNEXPECTED_CHARACTER?;
			case '"':
				break LOOP;
			case '\\':
				break;
			default:
				context.last_string.append(c);
				continue;
		}
		c = read_next(context)!;
		switch (c)
		{
			case '\0':
				return io::EOF?;
			case 1..31:
				return UNEXPECTED_CHARACTER?;
			case '"':
			case '\\':
			case '/':
				break;
			case 'b':
				c = '\b';
			case 'f':
				c = '\f';
			case 'n':
				c = '\n';
			case 'r':
				c = '\r';
			case 't':
				c = '\t';
			case 'u':
				uint val;
				for (int i = 0; i < 4; i++)
				{
					c = read_next(context)!;
					if (!c.is_xdigit()) return INVALID_ESCAPE_SEQUENCE?;
					val = val << 4 + (c > '9' ? (c | 32) - 'a' + 10 : c - '0');
				}
				context.last_string.append_char32(val);
				continue;
			default:
				 return INVALID_ESCAPE_SEQUENCE?;
		}
		context.last_string.append(c);
	}
	return STRING;
}