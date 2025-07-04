module c3json;
import std::io;
import std::collections::object;

import std::io::path;
import std::io::file;
import std::collections::list;
import std::time;
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
    Object*? parsed_result = json::tparse_string((String)content);
    bool parse_succeeded = !@catch(parsed_result);

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

// Test a single JSON file from jsonchecker directory
fn void test_jsonchecker_file(String filepath, TestResults* results)
{
    results.total_tests++;

    // Extract filename from path
    String filename = path::new(allocator::heap(), filepath)!!.basename();

    // Determine expected behavior based on filename prefix
    bool should_accept;
    bool should_skip = false;

    if (filename.starts_with("fail"))
    {
        should_accept = false;
        // Skip files with _EXCLUDE suffix as they might be special cases
        if (filename.contains("_EXCLUDE"))
        {
            should_skip = true;
        }
    }
    else if (filename.starts_with("pass"))
    {
        should_accept = true;
    }
    else
    {
        io::printfn("SKIP: Unknown prefix for file %s", filename);
        results.skipped_tests++;
        return;
    }

    if (should_skip)
    {
        io::printfn("SKIP: %s (excluded file)", filename);
        results.skipped_tests++;
        return;
    }

    // Read the JSON file content
    char[] content = file::load_temp(filepath)!!;

    // Try to parse the JSON
    Object*? parsed_result = json::tparse_string((String)content);
    bool parse_succeeded = !@catch(parsed_result);

    // Check the result against expectations
    if (parse_succeeded == should_accept)
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

// Test a single large JSON file for performance
fn void test_performance_file(String filepath, TestResults* results)
{
    results.total_tests++;

    // Extract filename from path
    String filename = path::new(allocator::heap(), filepath)!!.basename();

    io::printfn("Testing performance: %s", filename);

    // Measure file loading time
    Clock load_start = clock::now();
    char[] content = file::load_temp(filepath)!!;
    NanoDuration load_time = load_start.mark();

    // Get file size for reporting
    usz file_size = content.len;

    // Measure parsing time
    Clock parse_start = clock::now();
    Object*? parsed_result = json::tparse_string((String)content);
    NanoDuration parse_time = parse_start.mark();

    bool parse_succeeded = !@catch(parsed_result);

    if (parse_succeeded)
    {
        io::printfn("  ✓ SUCCESS: %s", filename);
        io::printfn("    File size: %d bytes (%.2f KB)", file_size, (double)file_size / 1024.0);
        io::printfn("    Load time: %s", load_time);
        io::printfn("    Parse time: %s", parse_time);
        io::printfn("    Total time: %s", load_time + parse_time);
        io::printfn("    Parse speed: %.2f MB/s", (double)file_size / (1024.0 * 1024.0) / parse_time.to_sec());
        results.passed_tests++;
    }
    else
    {
        io::printfn("  ❌ FAILED: %s", filename);
        io::printfn("    File size: %d bytes (%.2f KB)", file_size, (double)file_size / 1024.0);
        io::printfn("    Load time: %s", load_time);
        io::printfn("    Parse time: %s (failed)", parse_time);
        results.failed_tests++;
    }

    io::printn("");
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

// Get all JSON files from the jsonchecker directory
fn String[] get_jsonchecker_files(Allocator allocator)
{
    String test_dir = "test/jsonchecker";

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

// Get all JSON files from the performance test data directory
fn String[] get_performance_test_files(Allocator allocator)
{
    String test_dir = "test/data";

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

// JSONChecker test function
fn void test_jsonchecker_suite()
{
    io::printn("Starting JSONChecker Test Suite");
    io::printn("===============================");

    TestResults results = {};

    // Get all jsonchecker test files
    String[] test_files = get_jsonchecker_files(allocator::heap());
    defer
    {
        foreach (file : test_files)
        {
            allocator::free(allocator::heap(), file);
        }
        allocator::free(allocator::heap(), test_files);
    }

    io::printfn("Found %d jsonchecker test files", test_files.len);
    io::printn("");

    // Test each file
    foreach (filepath : test_files)
    {
        test_jsonchecker_file(filepath, &results);
    }

    // Print summary
    io::printn("");
    io::printn("JSONChecker Test Summary");
    io::printn("========================");
    io::printfn("Total tests: %d", results.total_tests);
    io::printfn("Passed: %d", results.passed_tests);
    io::printfn("Failed: %d", results.failed_tests);
    io::printfn("Skipped: %d", results.skipped_tests);

    if (results.failed_tests > 0)
    {
        io::printfn("❌ %d tests failed", results.failed_tests);
    }
    else
    {
        io::printn("All tests passed! ✓");
    }
}

// Performance test function
fn void test_performance_suite()
{
    io::printn("Starting JSON Performance Test Suite");
    io::printn("====================================");

    TestResults results = {};

    // Get all performance test files
    String[] test_files = get_performance_test_files(allocator::heap());
    defer
    {
        foreach (file : test_files)
        {
            allocator::free(allocator::heap(), file);
        }
        allocator::free(allocator::heap(), test_files);
    }

    io::printfn("Found %d large JSON test files", test_files.len);
    io::printn("");

    // Measure total time for all tests
    Clock total_start = clock::now();

    // Test each file
    foreach (filepath : test_files)
    {
        test_performance_file(filepath, &results);
    }

    NanoDuration total_time = total_start.mark();

    // Print summary
    io::printn("Performance Test Summary");
    io::printn("========================");
    io::printfn("Total tests: %d", results.total_tests);
    io::printfn("Passed: %d", results.passed_tests);
    io::printfn("Failed: %d", results.failed_tests);
    io::printfn("Total execution time: %s", total_time);

    if (results.failed_tests > 0)
    {
        io::printfn("❌ %d performance tests failed", results.failed_tests);
    }
    else
    {
        io::printn("All performance tests passed! ✓");
    }
}


fn int main(String[] args)
{
    test_json_parsing_suite();
    io::printn("");
    io::printn("");
    test_jsonchecker_suite();
    io::printn("");
    io::printn("");
    test_performance_suite();
    return 0;
}
