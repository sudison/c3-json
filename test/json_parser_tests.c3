module json_parser_tests @test;
import json_test_helpers;

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
