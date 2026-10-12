-- 极简断言骨架。只做三件事：收集用例、跑、汇总退出码。
-- 刻意不引第三方框架：回归防线不该押在小众包的维护状况上。
--
-- 注意：这是单例（Lune 的 require 有缓存），所有 spec 共用同一份 suites。
-- 因此 spec 文件只负责注册，绝不能自己调 run()——
-- 否则第二个 spec 会把第一个的用例重跑一遍、通过数翻倍。
-- 统一由 test/run.luau 在加载完全部 spec 后调用一次。

local harness = {}

-- Lune 0.10.5 不提供任何全局（process / fs 等），一律 require。
-- 用全局 process 会得到 "attempt to index nil with 'exit'"。
local process = require("@lune/process")

local suites = {}
local currentSuite = nil
local failures = {}
local passed = 0

function harness.describe(name, fn)
	currentSuite = { name = name, cases = {} }
	table.insert(suites, currentSuite)
	fn()
	currentSuite = nil
end

function harness.it(name, fn)
	assert(currentSuite, "it() 必须写在 describe() 内部")
	table.insert(currentSuite.cases, { name = name, fn = fn })
end

local expectValue = {}
expectValue.__index = expectValue

local function fail(msg)
	error(msg, 3)
end

function expectValue:toBe(expected)
	if self.value ~= expected then
		fail(string.format("期望 %s，实际 %s", tostring(expected), tostring(self.value)))
	end
end

function expectValue:toEqual(expected)
	local function deepEq(a, b)
		if type(a) ~= type(b) then return false end
		-- Vector2 / Vector3 等是非 table 类型，直接比相等
		if type(a) ~= "table" then return a == b end
		for k, v in pairs(a) do
			if not deepEq(v, b[k]) then return false end
		end
		for k in pairs(b) do
			if a[k] == nil then return false end
		end
		return true
	end
	if not deepEq(self.value, expected) then
		fail("深比较不相等")
	end
end

function expectValue:toBeTruthy()
	if not self.value then fail("期望真值，实际 " .. tostring(self.value)) end
end

function expectValue:toThrow()
	if type(self.value) ~= "function" then fail("toThrow 需要一个函数") end
	local ok = pcall(self.value)
	if ok then fail("期望抛出错误，但没有") end
end

function harness.expect(value)
	return setmetatable({ value = value }, expectValue)
end

function harness.run()
	for _, suite in ipairs(suites) do
		for _, case in ipairs(suite.cases) do
			local ok, err = pcall(case.fn)
			if ok then
				passed += 1
			else
				table.insert(failures, string.format("%s > %s\n    %s", suite.name, case.name, tostring(err)))
			end
		end
	end

	print(string.format("\n%d 通过，%d 失败\n", passed, #failures))
	for _, f in ipairs(failures) do
		print("失败: " .. f)
	end

	if #failures > 0 then
		process.exit(1)
	end
end

return harness
