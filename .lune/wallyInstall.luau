--[[
	https://github.com/Corecii/GreenTea/blob/main/lune/wally-install.luau

	Copyright 2024 Shae A.

	Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

local process = require("@lune/process")
local task = require("@lune/task")

local args = process.args
local isProd = args[1] == true

local function pipeProcess(process: process.ChildProcess)
	local stdout = process.stdout
	local stderr = process.stderr

	local function pipe(stream: typeof(stdout))
		local value
		local newLine = ""

		repeat
			value = stream:read(1)
			if value and value ~= "\r" and value ~= "\n" then
				newLine ..= value
			end

			if value == "\n" then
				print(newLine)
				newLine = ""
			end

		until not value
	end

	task.spawn(pipe, stdout)
	task.spawn(pipe, stderr)
end

local function exec(cmdline: string)
	local pieces = {}
	for piece in string.gmatch(" " .. cmdline, "%s+([^%s]+)") do
		table.insert(pieces, piece)
	end

	local program = table.remove(pieces, 1)
	assert(program ~= nil, "cmdline must include a program")

	print("> " .. cmdline)

	local result = process.create(program, pieces, {
		stdio = "inherit",
	})

	pipeProcess(result)

	if not result:status().ok then
		process.exit(result:status().code)
	end
end

local projectJson = "default.project.json"

exec("wally install")
exec(`rojo sourcemap -o sourcemap.json ./{projectJson}`)
exec("wally-package-types --sourcemap sourcemap.json ./Packages/")
-- exec("wally-package-types --sourcemap sourcemap.json ./ServerPackages/")
-- exec("wally-package-types --sourcemap sourcemap.json ./DevPackages/")
-- exec("wally-patch-package")
