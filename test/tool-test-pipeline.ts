#!/usr/bin/env bun
/**
 * Tool Test Pipeline for OpenCode
 * Runs OpenCode's tests in their environment, then runs same tests against our implementation
 */

import { spawn } from "bun"
import { readFileSync, existsSync } from "fs"
import { join } from "path"

interface TestResult {
  passed: boolean
  error?: string
  output?: string
}

interface TestCase {
  content: string
  find: string
  replace: string
  all?: boolean
  fail?: boolean
}

class ToolTestPipeline {
  private toolName: string
  private openCodeDir: string
  private zigBinary: string

  constructor(toolName: string) {
    this.toolName = toolName
    this.openCodeDir = join(import.meta.dir, "../opencode")
    this.zigBinary = join(import.meta.dir, "../zig-out/bin/z_toolkit_test")
  }

  async runOpenCodeTests(): Promise<{ success: boolean; output: string }> {
    console.log(`🧪 Running OpenCode ${this.toolName} tests...`)
    
    const proc = spawn({
      cmd: ["bun", "test", `packages/opencode/test/tool/${this.toolName}.test.ts`],
      cwd: this.openCodeDir,
      stdout: "pipe",
      stderr: "pipe",
    })

    const output = await new Response(proc.stdout).text()
    const stderr = await new Response(proc.stderr).text()
    const exitCode = await proc.exited

    console.log(`OpenCode tests exit code: ${exitCode}`)
    if (stderr) console.log("OpenCode stderr:", stderr)

    return {
      success: exitCode === 0,
      output: output + stderr
    }
  }

  extractTestCases(): TestCase[] {
    console.log(`📝 Extracting test cases from OpenCode...`)
    
    const testFilePath = join(this.openCodeDir, `packages/opencode/test/tool/${this.toolName}.test.ts`)
    if (!existsSync(testFilePath)) {
      throw new Error(`Test file not found: ${testFilePath}`)
    }

    const testFile = readFileSync(testFilePath, 'utf8')
    
    // Extract the testCases array
    const testCasesMatch = testFile.match(/const testCases[^=]*=\s*\[([\s\S]*?)\];?\s*(?:describe|$)/m)
    if (!testCasesMatch) {
      throw new Error("Could not extract test cases from test file")
    }

    try {
      // Use eval to parse the test cases (in a controlled environment)
      const testCasesCode = `const testCases = [${testCasesMatch[1]}]; testCases`
      const testCases = eval(testCasesCode)
      console.log(`✅ Extracted ${testCases.length} test cases`)
      return testCases
    } catch (error: any) {
      throw new Error(`Failed to parse test cases: ${error.message}`)
    }
  }

  async testZigImplementation(testCase: TestCase, index: number = -1): Promise<TestResult> {
    if (!existsSync(this.zigBinary)) {
      throw new Error(`Zig binary not found: ${this.zigBinary}`)
    }

    const input = JSON.stringify({
      content: testCase.content,
      oldString: testCase.find,
      newString: testCase.replace,
      replaceAll: testCase.all || false
    })
    
    // Debug first test case JSON
    if (index === 0) {
      console.log(`JSON being sent: ${input}`)
    }

    try {
      const proc = spawn({
        cmd: [this.zigBinary],
        stdin: "pipe",
        stdout: "pipe",
        stderr: "pipe",
      })

      proc.stdin.write(input)
      proc.stdin.end()

      const output = await new Response(proc.stdout).text()
      const stderr = await new Response(proc.stderr).text()
      const exitCode = await proc.exited

      if (exitCode === 0) {
        return { passed: true, output: output.trim() }
      } else {
        return { passed: false, error: stderr.trim(), output: output.trim() }
      }
    } catch (error: any) {
      return { passed: false, error: error.message }
    }
  }

  async runComparisonTests(): Promise<void> {
    console.log(`\n🔄 Running comparison tests for ${this.toolName} tool`)
    
    // Extract test cases
    const testCases = this.extractTestCases()
    
    let totalTests = 0
    let zigPassed = 0
    let matchedExpectations = 0

    for (let i = 0; i < testCases.length; i++) {
      const testCase = testCases[i]
      totalTests++

      console.log(`\n=== Test Case ${i + 1} ===`)
      console.log(`Content: ${testCase.content.substring(0, 50)}${testCase.content.length > 50 ? '...' : ''}`)
      console.log(`Find: ${testCase.find.substring(0, 30)}${testCase.find.length > 30 ? '...' : ''}`)
      console.log(`Replace: ${testCase.replace.substring(0, 30)}${testCase.replace.length > 30 ? '...' : ''}`)
      console.log(`ReplaceAll: ${testCase.all || false}`)
      console.log(`Should Fail: ${testCase.fail || false}`)

      const result = await this.testZigImplementation(testCase, i)
      const shouldFail = testCase.fail || false

      let testPassed = false
      if (shouldFail) {
        // Test should fail
        testPassed = !result.passed
      } else {
        // Test should succeed and contain the replacement
        testPassed = result.passed && (result.output?.includes(testCase.replace) || false)
      }

      console.log(`Zig Result: ${result.passed ? '✅ SUCCESS' : '❌ FAILED'}`)
      if (result.error) {
        console.log(`Error: ${result.error}`)
      }
      if (result.output) {
        console.log(`Output: ${result.output.substring(0, 100)}${result.output.length > 100 ? '...' : ''}`)
      }
      
      // Debug first test case
      if (i === 0) {
        console.log(`=== DEBUG FIRST TEST ===`)
        console.log(`Result passed: ${result.passed}`)
        console.log(`Result output: "${result.output || 'NO OUTPUT'}"`)
        console.log(`Looking for: "${testCase.replace}"`)
        console.log(`Should fail: ${shouldFail}`)
        if (result.output) {
          const containsReplacement = result.output.includes(testCase.replace)
          console.log(`Contains replacement? ${containsReplacement}`)
        }
      }
      
      console.log(`Expected Behavior: ${testPassed ? '✅ CORRECT' : '❌ INCORRECT'}`)

      if (result.passed) zigPassed++
      if (testPassed) matchedExpectations++
    }

    // Summary
    console.log(`\n\n📈 COMPARISON SUMMARY`)
    console.log(`==========================================`)
    console.log(`Tool:                    ${this.toolName}`)
    console.log(`Total Test Cases:        ${totalTests}`)
    console.log(`Zig Tests Passed:        ${zigPassed}/${totalTests} (${Math.round(zigPassed/totalTests*100)}%)`)
    console.log(`Matched Expectations:    ${matchedExpectations}/${totalTests} (${Math.round(matchedExpectations/totalTests*100)}%)`)
    
    if (matchedExpectations === totalTests) {
      console.log(`\n🎉 SUCCESS: Zig implementation matches all expected behaviors!`)
    } else {
      console.log(`\n⚠️  ${totalTests - matchedExpectations} test cases don't match expected behavior`)
    }
  }

  async runFullPipeline(): Promise<void> {
    console.log(`🚀 Starting Tool Test Pipeline for: ${this.toolName}`)
    
    // Step 1: Try to run OpenCode tests (informational)
    try {
      await this.runOpenCodeTests()
    } catch (error: any) {
      console.log(`⚠️  Could not run OpenCode tests directly: ${error.message}`)
      console.log(`Proceeding with test case extraction...`)
    }

    // Step 2: Run comparison tests
    await this.runComparisonTests()
  }
}

// CLI
async function main() {
  const toolName = process.argv[2] || "edit"
  
  const supportedTools = ["edit"]
  if (!supportedTools.includes(toolName)) {
    console.error(`❌ Unknown tool: ${toolName}`)
    console.log(`Available tools: ${supportedTools.join(", ")}`)
    process.exit(1)
  }

  try {
    const pipeline = new ToolTestPipeline(toolName)
    await pipeline.runFullPipeline()
  } catch (error: any) {
    console.error(`❌ Pipeline failed: ${error.message}`)
    process.exit(1)
  }
}

if (import.meta.main) {
  main()
}

export { ToolTestPipeline }