#!/usr/bin/env lua
-- Test runner for the html5lib tree-construction test suite.
-- Don't run directly, use `make check-html5lib` in the top-level directory.

assert(arg[1], "No test files specified")
local gumbo = require "gumbo"
local serialize = require "gumbo.serialize.html5lib"
local util = require "gumbo.serialize.util"
local Buffer = util.Buffer
local verbose = os.getenv "VERBOSE"
local results = {passed = 0, failed = 0, skipped = 0}
local start = os.clock()

local function printf(...)
    io.stdout:write(string.format(...))
end

local function parse_testdata(filename)
    local file = assert(io.open(filename))
    local text = assert(file:read("*a"))
    file:close()
    local tests = {[0] = {}}
    local buffer = Buffer()
    local field = false
    local i = 0
    local linenumber = 0
    for line in text:gmatch "([^\n]*)\n" do
        linenumber = linenumber + 1
        local section = line:match("^#(.*)$")
        if section then
            tests[i][field] = buffer:concat("\n")
            buffer = Buffer()
            field = section
            if section == "data" then
                i = i + 1
                tests[i] = {line = linenumber}
            end
        else
            buffer:append(line)
        end
    end
    tests[i][field] = buffer:concat("\n") .. "\n"
    if i > 0 then
        tests.n = i
        return tests
    else
        return nil, "No test data found in " .. filename
    end
end

for i = 1, #arg do
    local filename = arg[i]
    local tests = assert(parse_testdata(filename))
    local passed, failed, skipped = 0, 0, 0
    for i = 1, tests.n do
        local test = tests[i]
        if
            -- Gumbo can't parse document fragments yet
            test["document-fragment"]
            -- See line 134 of python/gumbo/html5lib_adapter_test.py
            or test.data:find("<noscript>", 1, true)
            or test.data:find("<command>", 1, true)
        then
            skipped = skipped + 1
        else
            local document = assert(gumbo.parse(test.data))
            local serialized = serialize(document)
            if serialized == test.document then
                passed = passed + 1
            else
                failed = failed + 1
                if verbose then
                    printf("%s\n", string.rep("=", 76))
                    printf("%s:%d: Test %d failed\n", filename, test.line, i)
                    printf("%s\n\n", string.rep("=", 76))
                    printf("Input:\n%s\n\n", test.data)
                    printf("Expected:\n%s\n", test.document)
                    printf("Received:\n%s\n", serialized)
                end
            end
        end
    end
    results[i] = {
        filename = filename,
        basename = filename:gsub("(.*/)(.*)", "%2"),
        passed = passed,
        failed = failed,
        skipped = skipped,
        total = tests.n
    }
    results.passed = results.passed + passed
    results.failed = results.failed + failed
    results.skipped = results.skipped + skipped
end

results.total = results.passed + results.failed + results.skipped

for i = 1, #results do
    local r = results[i]
    if r.failed > 0 then
        printf("%s: %d of %d tests failed\n", r.basename, r.failed, r.total)
    end
end

printf("\nRan %d tests in %.2fs\n\n", results.total, os.clock() - start)
printf("Passed: %d\n", results.passed)
printf("Failed: %d\n", results.failed)
printf("Skipped: %d\n\n", results.skipped)
os.exit(results.failed == 0 and 0 or 1)
