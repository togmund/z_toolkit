// import { Tool } from "@opencode/sdk"
// import { spawn } from "child_process"
// import { promisify } from "util"
// import * as path from "path"
// import * as fs from "fs"

// const execAsync = promisify(spawn)

// // Path to the compiled Zig binary
// const BINARY_PATH = path.join(__dirname, "../../zig-out/bin/z_toolkit_test")

// export const ZigEditTool = Tool.define("edit", {
//   description: "High-performance Zig implementation of the edit tool",
//   parameters: {
//     filePath: { type: "string", description: "The absolute path to the file to modify" },
//     oldString: { type: "string", description: "The text to replace" },
//     newString: { type: "string", description: "The text to replace it with" },
//     replaceAll: { type: "boolean", optional: true, description: "Replace all occurrences" }
//   },

//   async execute(params, ctx) {
//     if (!params.filePath) {
//       throw new Error("filePath is required")
//     }

//     if (params.oldString === params.newString) {
//       throw new Error("oldString and newString must be different")
//     }

//     // Ensure binary exists
//     if (!fs.existsSync(BINARY_PATH)) {
//       throw new Error(`Zig binary not found at ${BINARY_PATH}. Run 'zig build' first.`)
//     }

//     // Read the file
//     if (!fs.existsSync(params.filePath)) {
//       throw new Error(`File ${params.filePath} not found`)
//     }

//     const contentOld = await fs.promises.readFile(params.filePath, 'utf8')

//     try {
//       // Call the Zig binary with the replacement
//       const result = await callZigReplace(contentOld, params.oldString, params.newString, params.replaceAll || false)

//       // Write the result back to the file
//       await fs.promises.writeFile(params.filePath, result)

//       return {
//         title: `Edited ${path.basename(params.filePath)}`,
//         output: "File successfully edited using Zig implementation"
//       }
//     } catch (error) {
//       // Fallback to original OpenCode implementation if Zig fails
//       console.warn("Zig implementation failed, falling back to JavaScript:", error.message)
//       throw error
//     }
//   }
// })

// async function callZigReplace(content: string, oldString: string, newString: string, replaceAll: boolean): Promise<string> {
//   return new Promise((resolve, reject) => {
//     const process = spawn(BINARY_PATH, [], {
//       stdio: ['pipe', 'pipe', 'pipe']
//     })

//     let stdout = ''
//     let stderr = ''

//     process.stdout.on('data', (data) => {
//       stdout += data.toString()
//     })

//     process.stderr.on('data', (data) => {
//       stderr += data.toString()
//     })

//     process.on('close', (code) => {
//       if (code === 0) {
//         resolve(stdout.trim())
//       } else {
//         reject(new Error(`Zig process failed with code ${code}: ${stderr}`))
//       }
//     })

//     process.on('error', (error) => {
//       reject(new Error(`Failed to spawn Zig process: ${error.message}`))
//     })

//     // Send input data as JSON
//     const input = JSON.stringify({
//       content,
//       oldString,
//       newString,
//       replaceAll
//     })

//     process.stdin.write(input)
//     process.stdin.end()
//   })
// }
