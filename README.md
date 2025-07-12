# C3 JSON Library

A high-performance JSON parsing, marshaling, and unmarshaling library for the C3 programming language.

## Features

- **JSON Parsing**: Parse JSON strings into Object structures
- **JSON Marshaling**: Convert C3 structs, arrays, and primitives to JSON strings
- **JSON Unmarshaling**: Directly parse JSON into C3 structs without intermediate Object allocation
- **Type Safety**: Compile-time type checking for marshal/unmarshal operations
- **Memory Efficient**: Direct parsing avoids unnecessary Object allocations
- **Comprehensive Type Support**: Primitives, enums, structs, arrays, slices, and nested structures
- **Standards Compliant**: Passes the [JSONTestSuite](https://github.com/nst/JSONTestSuite) conformance tests
- **Well Tested**: Comprehensive unit test coverage for all functionality

## Quick Start

### Basic Usage

```c3
import json;

// Define your data structure
struct Person {
    String name;
    int age;
    bool active;
    String[] tags;
}

// Marshal struct to JSON
Person person = { .name = "John", .age = 30, .active = true, .tags = {"developer", "c3"} };
DString json_output = dstring::new();
json::marshal(person, &json_output)!!;
// Result: {"name":"John","age":30,"active":true,"tags":["developer","c3"]}

// Unmarshal JSON to struct
String json_input = `{"name":"Jane","age":25,"active":false,"tags":["designer"]}`;
Person result = json::unmarshal(Person, json_input, allocator)!!;
```

## Supported Types

### Primitive Types
- **Integers**: `int`, `uint`, `i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`, `u64`
- **Floating Point**: `float`, `double`
- **Boolean**: `bool`
- **Strings**: `String`

### Complex Types
- **Enums**: Marshaled as string names, unmarshaled by name lookup
- **Structs**: Recursive marshaling/unmarshaling of all fields
- **Arrays**: Both fixed arrays (`int[5]`) and slices (`int[]`)
- **Nested Structures**: Full support for nested structs and arrays

### Example with Complex Types

```c3
enum Status { ACTIVE, INACTIVE, PENDING }

struct Address {
    String street;
    String city;
    int zip_code;
}

struct User {
    String name;
    int age;
    Status status;
    Address address;
    String[] tags;
    int[3] scores;  // Fixed array
}

// All types are automatically handled
User user = { /* ... */ };
DString json = dstring::new();
json::marshal(user, &json)!!;

// Unmarshal back
User parsed = json::unmarshal(User, json.str_view(), allocator)!!;
```

## API Reference

### Marshaling

```c3
// Marshal any supported type to JSON
macro void? marshal(value, DString* output)
```

**Parameters:**
- `value`: The value to marshal (struct, array, primitive, etc.)
- `output`: DString to append the JSON output to

**Example:**
```c3
DString result = dstring::new();
json::marshal(my_struct, &result)!!;
String json = result.str_view();
```

### Unmarshaling

```c3
// Unmarshal JSON string directly to target type
macro unmarshal($TargetType, String json_string, Allocator allocator)
```

**Parameters:**
- `$TargetType`: The target type to unmarshal to
- `json_string`: The JSON string to parse
- `allocator`: Allocator for memory allocation

**Returns:** The unmarshaled value of type `$TargetType`

**Example:**
```c3
MyStruct result = json::unmarshal(MyStruct, json_string, allocator)!!;
```

## Memory Management

### Allocators
- **Persistent Data**: Use your main allocator for data that needs to persist
- **Temporary Data**: Use `tmem` for temporary parsing operations
- **Testing**: Use `tmem` in tests for automatic cleanup

### Example
```c3
// For persistent data
MyStruct data = json::unmarshal(MyStruct, json, heap_allocator)!!;

// For temporary operations
MyStruct temp = json::unmarshal(MyStruct, json, tmem)!!;
// Automatically cleaned up
```

## Error Handling

The library uses C3's fault system for error handling:

```c3
// Handle parsing errors
if (catch err = json::unmarshal(MyStruct, invalid_json, allocator)) {
    switch (err) {
        case json::TYPE_MISMATCH:
            io::printn("Type mismatch in JSON");
        case json::UNEXPECTED_CHARACTER:
            io::printn("Invalid JSON syntax");
        default:
            io::printn("Other JSON error");
    }
}
```

## Advanced Features

### Unknown Field Handling
The unmarshaler automatically skips JSON fields that don't exist in the target struct:

```c3
struct SimpleStruct { String name; int age; }

// This JSON has extra fields that will be ignored
String json = `{"name":"John","age":30,"unknown_field":"ignored","extra_array":[1,2,3]}`;
SimpleStruct result = json::unmarshal(SimpleStruct, json, allocator)!!;
// Only name and age are populated, extra fields are safely skipped
```

### Fixed vs Dynamic Arrays
```c3
struct ArrayExample {
    int[5] fixed_array;    // Must have exactly 5 or fewer elements
    int[] dynamic_array;   // Can have any number of elements
}
```

### Enum Marshaling
Enums are always marshaled as their string names:

```c3
enum Color { RED, GREEN, BLUE }
struct Item { Color color; }

Item item = { .color = Color.RED };
// Marshals to: {"color":"RED"}
```

### String Unescaping
JSON string escape sequences are automatically handled:

```c3
// JSON: {"message": "Hello \"World\"\nNew Line\tTab\\Backslash"}
// Becomes: Hello "World"
//          New Line	Tab\Backslash
```

## Building and Testing

```bash
# Build the library
c3c build

# Run tests
c3c test
```

## Performance

- **Direct Unmarshaling**: Bypasses Object allocation for better performance
- **Memory Efficient**: Minimal allocations during parsing
- **Type Safe**: Compile-time type checking prevents runtime errors
- **Zero-Copy**: String handling avoids unnecessary copying where possible

## Examples

### Round-trip Testing
```c3
// Original data
MyStruct original = { /* ... */ };

// Marshal to JSON
DString json = dstring::new();
json::marshal(original, &json)!!;

// Unmarshal back
MyStruct restored = json::unmarshal(MyStruct, json.str_view(), allocator)!!;

// Data should be identical (except for floating-point precision limits)
```

### Error Handling Example
```c3
String invalid_json = `{"name": "John", "age": "not_a_number"}`;

if (catch err = json::unmarshal(Person, invalid_json, allocator)) {
    io::printfn("Failed to parse JSON: %s", err);
    // Handle error appropriately
}
```

## License

This library is part of the C3 standard library and follows the same licensing terms.