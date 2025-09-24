#!/usr/bin/env bun
import { spawn } from "child_process"
import { promisify } from "util"
import * as path from "path"

// Import OpenCode's original implementation
const opencodePath = path.join(__dirname, "../opencode/packages/opencode/src/tool/edit.ts")
let openCodeReplace: any

try {
  // Try to import the OpenCode implementation
  const { replace } = await import(opencodePath)
  openCodeReplace = replace
} catch (error) {
  console.error("Could not import OpenCode implementation:", error.message)
  console.log("Falling back to mock implementation for comparison")
  // Mock implementation for comparison
  openCodeReplace = (content: string, find: string, replace: string, all?: boolean) => {
    if (find === replace) throw new Error("oldString and newString must be different")
    if (find === "") throw new Error("oldString cannot be empty") 
    if (content.indexOf(find) === -1) throw new Error("String not found")
    return all ? content.replaceAll(find, replace) : content.replace(find, replace)
  }
}

interface TestCase {
  content: string
  find: string
  replace: string
  all?: boolean
  fail?: boolean
}

// The exact same test cases from OpenCode's test suite
const testCases: TestCase[] = [
  // SimpleReplacer cases
  {
    content: ["function hello() {", '  console.log("world");', "}"].join("\n"),
    find: 'console.log("world");',
    replace: 'console.log("universe");',
  },
  {
    content: ["if (condition) {", "  doSomething();", "  doSomethingElse();", "}"].join("\n"),
    find: ["  doSomething();", "  doSomethingElse();"].join("\n"),
    replace: ["  doNewThing();", "  doAnotherThing();"].join("\n"),
  },

  // LineTrimmedReplacer cases
  {
    content: ["function test() {", '    console.log("hello");', "}"].join("\n"),
    find: 'console.log("hello");',
    replace: 'console.log("goodbye");',
  },
  {
    content: ["const x = 5;   ", "const y = 10;"].join("\n"),
    find: "const x = 5;",
    replace: "const x = 15;",
  },
  {
    content: ["  if (true) {", "    return false;", "  }"].join("\n"),
    find: ["if (true) {", "return false;", "}"].join("\n"),
    replace: ["if (false) {", "return true;", "}"].join("\n"),
  },

  // WhitespaceNormalizedReplacer cases
  {
    content: ["function test() {", '\tconsole.log("hello");', "}"].join("\n"),
    find: '  console.log("hello");',
    replace: '  console.log("world");',
  },
  {
    content: "const   x    =     5;",
    find: "const x = 5;",
    replace: "const x = 10;",
  },
  {
    content: "if\t(  condition\t) {",
    find: "if ( condition ) {",
    replace: "if (newCondition) {",
  },

  // IndentationFlexibleReplacer cases
  {
    content: ["    function nested() {", '      console.log("deeply nested");', "      return true;", "    }"].join(
      "\n",
    ),
    find: ["function nested() {", '  console.log("deeply nested");', "  return true;", "}"].join("\n"),
    replace: ["function nested() {", '  console.log("updated");', "  return false;", "}"].join("\n"),
  },
  {
    content: ["  if (true) {", '    console.log("level 1");', '      console.log("level 2");', "  }"].join("\n"),
    find: ["if (true) {", 'console.log("level 1");', '  console.log("level 2");', "}"].join("\n"),
    replace: ["if (true) {", 'console.log("updated");', "}"].join("\n"),
  },

  // replaceAll option cases
  {
    content: ['console.log("test");', 'console.log("test");', 'console.log("test");'].join("\n"),
    find: 'console.log("test");',
    replace: 'console.log("updated");',
    all: true,
  },
  {
    content: ['console.log("test");', 'console.log("test");'].join("\n"),
    find: 'console.log("test");',
    replace: 'console.log("updated");',
    all: false,
  },

  // Error cases
  {
    content: 'console.log("hello");',
    find: "nonexistent string",
    replace: "updated",
    fail: true,
  },
  {
    content: ["test", "test", "different content", "test"].join("\n"),
    find: "test",
    replace: "updated",
    all: false,
    fail: true,
  },

  // Edge cases
  {
    content: "",
    find: "",
    replace: "new content",
  },
  {
    content: "const regex = /[.*+?^${}()|[\\\\]\\\\\\\\]/g;",
    find: "/[.*+?^${}()|[\\\\]\\\\\\\\]/g",
    replace: "/\\\\w+/g",
  },
  {
    content: 'const message = "Hello 世界! 🌍";',
    find: "Hello 世界! 🌍",
    replace: "Hello World! 🌎",
  },

  // EscapeNormalizedReplacer cases
  {
    content: 'console.log("Hello\nWorld");',
    find: 'console.log("Hello\\nWorld");',
    replace: 'console.log("Hello\nUniverse");',
  },
  {
    content: "const str = 'It's working';",
    find: "const str = 'It\\'s working';",
    replace: "const str = 'It's fixed';",
  },
  {
    content: "const template = `Hello ${name}`;",
    find: "const template = `Hello \\${name}`;",
    replace: "const template = `Hi ${name}`;",
  },
  {
    content: "const path = 'C:\\Users\\test';",
    find: "const path = 'C:\\\\Users\\\\test';",
    replace: "const path = 'C:\\Users\\admin';",
  },

  // Test for same oldString and newString (should fail)
  {
    content: 'console.log("test");',
    find: 'console.log("test");',
    replace: 'console.log("test");',
    fail: true,
  },

  // Test validation for empty strings with same oldString and newString
  {
    content: "",
    find: "",
    replace: "",
    fail: true,
  },

  // Test multiple occurrences with replaceAll=false (should fail)
  {
    content: ["const a = 1;", "const b = 1;", "const c = 1;"].join("\n"),
    find: "= 1",
    replace: "= 2",
    all: false,
    fail: true,
  },
]

const BINARY_PATH = path.join(__dirname, "../zig-out/bin/z_toolkit_test")

async function callZigReplace(content: string, oldString: string, newString: string, replaceAll: boolean): Promise<string> {
  return new Promise((resolve, reject) => {
    const process = spawn(BINARY_PATH, [], {
      stdio: ['pipe', 'pipe', 'pipe']
    })
    
    let stdout = ''
    let stderr = ''
    
    process.stdout.on('data', (data) => {
      stdout += data.toString()
    })
    
    process.stderr.on('data', (data) => {
      stderr += data.toString()
    })
    
    process.on('close', (code) => {
      if (code === 0) {
        resolve(stdout.trim())
      } else {
        reject(new Error(`Zig process failed with code ${code}: ${stderr}`))
      }
    })
    
    process.on('error', (error) => {
      reject(new Error(`Failed to spawn Zig process: ${error.message}`))
    })
    
    // Send input data as JSON
    const input = JSON.stringify({
      content,
      oldString,
      newString,
      replaceAll
    })
    
    process.stdin.write(input, 'utf8')
    process.stdin.end()
  })
}

async function runTest(testCase: TestCase, index: number) {
  console.log(`\n=== Test Case ${index + 1} ===`)
  console.log(`Content: ${testCase.content.substring(0, 50)}${testCase.content.length > 50 ? '...' : ''}`)
  console.log(`Find: ${testCase.find.substring(0, 30)}${testCase.find.length > 30 ? '...' : ''}`)
  console.log(`Replace: ${testCase.replace.substring(0, 30)}${testCase.replace.length > 30 ? '...' : ''}`)
  console.log(`ReplaceAll: ${testCase.all || false}`)
  console.log(`Should Fail: ${testCase.fail || false}`)
  
  let openCodeResult: any = null
  let openCodeError: string | null = null
  let zigResult: any = null
  let zigError: string | null = null
  
  // Test OpenCode implementation
  try {
    openCodeResult = openCodeReplace(testCase.content, testCase.find, testCase.replace, testCase.all)
  } catch (error: any) {
    openCodeError = error.message
  }
  
  // Test Zig implementation
  try {
    zigResult = await callZigReplace(testCase.content, testCase.find, testCase.replace, testCase.all || false)
  } catch (error: any) {
    zigError = error.message
  }
  
  // Compare results
  const openCodePassed = testCase.fail ? (openCodeError !== null) : (openCodeError === null && openCodeResult?.includes(testCase.replace))
  const zigPassed = testCase.fail ? (zigError !== null) : (zigError === null && zigResult?.includes(testCase.replace))
  
  console.log(`\n📊 Results:`)
  console.log(`OpenCode: ${openCodePassed ? '✅ PASS' : '❌ FAIL'}`)
  if (openCodeError) console.log(`  Error: ${openCodeError}`)
  else if (openCodeResult) console.log(`  Result: ${openCodeResult.substring(0, 50)}${openCodeResult.length > 50 ? '...' : ''}`)
  
  console.log(`Zig:      ${zigPassed ? '✅ PASS' : '❌ FAIL'}`)
  if (zigError) console.log(`  Error: ${zigError}`)
  else if (zigResult) console.log(`  Result: ${zigResult.substring(0, 50)}${zigResult.length > 50 ? '...' : ''}`)
  
  // Check if results match
  const resultsMatch = (openCodePassed === zigPassed) && 
    ((openCodeError !== null) === (zigError !== null)) &&
    (openCodeResult === zigResult || (testCase.fail && openCodeError && zigError))
  
  console.log(`Match:    ${resultsMatch ? '✅ IDENTICAL' : '❌ DIFFERENT'}`)
  
  return {
    index: index + 1,
    openCodePassed,
    zigPassed,
    resultsMatch,
    openCodeError,
    zigError,
    openCodeResult,
    zigResult
  }
}

async function main() {
  console.log("🧪 Running Comprehensive Test Suite")
  console.log("Comparing Zig implementation vs OpenCode JavaScript implementation")
  console.log(`Total test cases: ${testCases.length}`)
  
  const results = []
  let openCodePassed = 0
  let zigPassed = 0
  let identical = 0
  
  for (let i = 0; i < testCases.length; i++) {
    const result = await runTest(testCases[i], i)
    results.push(result)
    
    if (result.openCodePassed) openCodePassed++
    if (result.zigPassed) zigPassed++
    if (result.resultsMatch) identical++
  }
  
  console.log(`\n\n📈 SUMMARY`)
  console.log(`==========================================`)
  console.log(`Total Tests:        ${testCases.length}`)
  console.log(`OpenCode Passed:    ${openCodePassed}/${testCases.length} (${Math.round(openCodePassed/testCases.length*100)}%)`)
  console.log(`Zig Passed:         ${zigPassed}/${testCases.length} (${Math.round(zigPassed/testCases.length*100)}%)`)
  console.log(`Identical Results:  ${identical}/${testCases.length} (${Math.round(identical/testCases.length*100)}%)`)
  
  if (identical === testCases.length) {
    console.log(`\n🎉 SUCCESS: Both implementations produce identical results on all tests!`)
  } else {
    console.log(`\n⚠️  DIFFERENCES FOUND: ${testCases.length - identical} test cases have different results`)
    
    console.log(`\nFailed/Different tests:`)
    results.forEach(result => {
      if (!result.resultsMatch) {
        console.log(`  Test ${result.index}: OpenCode=${result.openCodePassed ? 'PASS' : 'FAIL'}, Zig=${result.zigPassed ? 'PASS' : 'FAIL'}`)
      }
    })
  }
}

main().catch(console.error)