module json_test_helpers;
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

// Test a single JSON file from test_parsing directory
fn void test_single_parsing_file(String filepath, TestResults* results)
{
    results.total_tests++;

    // Extract filename from path
    String filename = path::new(tmem, filepath)!!.basename();

    // Skip files with _EXCLUDE suffix
    if (filename.contains("_EXCLUDE"))
    {
        results.skipped_tests++;
        return;
    }

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
        results.passed_tests++;
    }
    else if (parse_succeeded == should_accept)
    {
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
fn void test_single_jsonchecker_file(String filepath, TestResults* results)
{
    results.total_tests++;

    // Extract filename from path
    String filename = path::new(tmem, filepath)!!.basename();

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
        results.skipped_tests++;
        return;
    }

    if (should_skip)
    {
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
fn String[] get_test_parsing_files()
{
    String test_dir = "resources/test_parsing";

    List{String} files;
    files.init(tmem);

    // List all files in the directory
    PathList dir_list = path::ls(tmem, path::new(tmem, test_dir)!!)!!;
    defer dir_list.free();

    foreach (path_entry : dir_list)
    {
        String filename = path_entry.basename();
        if (filename.ends_with(".json"))
        {
            String full_path = test_dir.tconcat("/").tconcat(filename);
            files.push(full_path.tcopy());
        }
    }

    return files.array_view();
}

// Get all JSON files from the jsonchecker directory
fn String[] get_jsonchecker_files()
{
    String test_dir = "resources/jsonchecker";

    List{String} files;
    files.init(tmem);

    // List all files in the directory
    PathList dir_list = path::ls(tmem, path::new(tmem, test_dir)!!)!!;
    defer dir_list.free();

    foreach (path_entry : dir_list)
    {
        String filename = path_entry.basename();
        if (filename.ends_with(".json"))
        {
            String full_path = test_dir.tconcat("/").tconcat(filename);
            files.push(full_path.tcopy());
        }
    }

    return files.array_view();
}
