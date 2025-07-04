module c3json;
import std::io;
import std::collections::object;

import std::io::path;
import std::io::file;
import std::collections::list;
import json;

// Test results tracking
struct TestResults
{
    int total_tests;
    int passed_tests;
    int failed_tests;
    int skipped_tests;
}

// Test a single JSON file
fn void test_json_file(String filepath, TestResults* results)
{
    results.total_tests++;

    // Extract filename from path
    String filename = path::new(allocator::heap(), filepath)!!.basename();

    // Determine expected behavior based on filename prefix
    bool should_accept;
    bool is_implementation_defined = false;

    if (filename.starts_with("y_"))
    {
        should_accept = true;
    }
    else if (filename.starts_with("n_"))
    {
        should_accept = false;
    }
    else if (filename.starts_with("i_"))
    {
        is_implementation_defined = true;
        should_accept = true; // We'll accept either outcome for these
    }
    else
    {
        io::printfn("SKIP: Unknown prefix for file %s", filename);
        results.skipped_tests++;
        return;
    }

    // Read the JSON file content
    char[] content = file::load_temp(filepath)!!;

    // Try to parse the JSON
    Object*? parsed_result = json::parse_string(mem, (String)content);
    bool parse_succeeded = !@catch(parsed_result);

    // Clean up if parsing succeeded
    if (parse_succeeded)
    {
        defer parsed_result!!.free();
    }

    // Check the result against expectations
    if (is_implementation_defined)
    {
        // For implementation-defined cases, any result is acceptable
        io::printfn("PASS: %s (implementation-defined, result: %s)",
                   filename, parse_succeeded ? "accepted" : "rejected");
        results.passed_tests++;
    }
    else if (parse_succeeded == should_accept)
    {
        io::printfn("PASS: %s (%s as expected)",
                   filename, should_accept ? "accepted" : "rejected");
        results.passed_tests++;
    }
    else
    {
        io::printfn("FAIL: %s (expected %s, got %s)",
                   filename,
                   should_accept ? "accept" : "reject",
                   parse_succeeded ? "accept" : "reject");
        results.failed_tests++;
    }
}

// Get all JSON files from the test_parsing directory
fn String[] get_test_files(Allocator allocator)
{
    String test_dir = "test/test_parsing";

    List{String} files;
    files.init(allocator);

    // List all files in the directory
    PathList dir_list = path::ls(allocator, path::new(allocator, test_dir)!!)!!;
    defer dir_list.free();

    foreach (path_entry : dir_list)
    {
        String filename = path_entry.basename();
        if (filename.ends_with(".json"))
        {
            String full_path = test_dir.tconcat("/").tconcat(filename);
            files.push(full_path.copy(allocator));
        }
    }

    return files.array_view();
}

// Main test function
fn void test_json_parsing_suite()
{
    io::printn("Starting JSON Parser Test Suite");
    io::printn("================================");

    TestResults results = {};

    // Get all test files
    String[] test_files = get_test_files(allocator::heap());
    defer
    {
        foreach (file : test_files)
        {
            allocator::free(allocator::heap(), file);
        }
        allocator::free(allocator::heap(), test_files);
    }

    io::printfn("Found %d test files", test_files.len);
    io::printn("");

    // Test each file
    foreach (filepath : test_files)
    {
        io::printfn("Testing: %s", filepath);
        test_json_file(filepath, &results);
    }

    // Print summary
    io::printn("");
    io::printn("Test Summary");
    io::printn("============");
    io::printfn("Total tests: %d", results.total_tests);
    io::printfn("Passed: %d", results.passed_tests);
    io::printfn("Failed: %d", results.failed_tests);
    io::printfn("Skipped: %d", results.skipped_tests);

    if (results.failed_tests > 0)
    {
    }
    else
    {
        io::printn("All tests passed! ✓");
    }
}


fn int main(String[] args)
{
	io::printn("Hello, World!");

    test_json_parsing_suite();
	return 0;
}
