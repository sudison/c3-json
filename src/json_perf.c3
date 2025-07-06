module json_perf;
import json;
import std::collections::list;
import std::io::path;
import std::io::file;
import std::collections::object;

// Get all JSON files from the performance test data directory
fn String[] get_performance_test_files(Allocator allocator)
{
    String test_dir = "resources/data";

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

fn void test_performance_suite()
{
    String[] test_files = get_performance_test_files(allocator::heap());
    defer
    {
        foreach (file : test_files)
        {
            allocator::free(allocator::heap(), file);
        }
        allocator::free(allocator::heap(), test_files);
    }

    foreach (filepath : test_files)
    {
        test_performance_file(filepath);
    }
}

// Test a single large JSON file for performance
fn void test_performance_file(String filepath)
{
    // Extract filename from path
    String filename = path::new(allocator::heap(), filepath)!!.basename();

    char[] content = file::load_temp(filepath)!!;
    // Get file size for reporting
    usz file_size = content.len;

    // Measure parsing time
    Object* parsed_result = json::tparse_string((String)content)!!;
    defer parsed_result.free();
}

fn void init() @init
{
    set_benchmark_warmup_iterations(5);
    set_benchmark_max_iterations(10);
}

fn void json_bench() @benchmark
{
	test_performance_suite();
}


