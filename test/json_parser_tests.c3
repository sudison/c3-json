module json_parser_tests @test;
import json_test_helpers;
import json;
import std::io;

// Test function for test_parsing directory files
fn void test_parsing_files()
{
    json_test_helpers::TestResults results = {};

    // Get all test files
    String[] test_files = json_test_helpers::get_test_parsing_files();

    // Test each file
    foreach (filepath : test_files)
    {
        json_test_helpers::test_single_parsing_file(filepath, &results);
    }

    // Assert that we have no failures for the test framework
    assert(results.failed_tests == 0, "JSON parser tests failed: %d failures", results.failed_tests);
}

// Test function for jsonchecker directory files
fn void test_jsonchecker_files()
{
    json_test_helpers::TestResults results = {};

    // Get all jsonchecker test files
    String[] test_files = json_test_helpers::get_jsonchecker_files();

    // Test each file
    foreach (filepath : test_files)
    {
        json_test_helpers::test_single_jsonchecker_file(filepath, &results);
    }

    // Assert that we have no failures for the test framework
    assert(results.failed_tests == 0, "JSONChecker tests failed: %d failures", results.failed_tests);
}

fn void test_null_bytes_rejected()
{
	// Test that null bytes in JSON are rejected (like n_multidigit_number_then_00.json)
	// This simulates "123" + null byte + newline

    char[] json_with_null = { '1', '2', '3', 0 };
    io::printfn("JSON: %s", json_with_null);

	ByteReader reader;
	reader.init(json_with_null[..]);

	if (catch err = json::parse(mem, &reader))
	{
		assert(err == json::UNEXPECTED_CHARACTER);
	}
	else
	{
		assert(false, "Expected UNEXPECTED_CHARACTER error for JSON with null byte");
	}
}