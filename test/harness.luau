-- 极简断言骨架（Roblox 版）。
--
-- 经 MCP 调用 require(ServerStorage.__tests.run) 拿到汇总表，
-- 而不是终止进程——Roblox 里没有 process，也没有任何 Lune 全局。
--
-- 单例：所有 spec 共用同一份 suites（ModuleScript 的 require 有缓存），
-- 所以 spec 只负责注册，绝不自己调 run()。
-- 若每个 spec 各调一次 run()，先前的用例会被重复执行、通过数翻倍。

local harness = {}

local suites = {}
local currentSuite = nil

function harness.describe(name, fn)
	local suite = { name = name, cases = {} }
	-- 同名 suite 覆盖而不是追加。require 有缓存，正常每个 spec 只注册一次；
	-- 但反复调试时同一个 spec 可能以不同实例被注册多次（旧实例的注册不会消失），
	-- 不去重就会重复计数、通过数翻倍。
	for i, existing in ipairs(suites) do
		if existing.name == name then
			suites[i] = suite
			currentSuite = suite
			fn()
			currentSuite = nil
			return
		end
	end
	table.insert(suites, suite)
	currentSuite = suite
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
		-- CFrame / Vector3 等非 table 类型直接比相等
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

function expectValue:toBeCloseTo(expected, tolerance)
	local t = tolerance or 1e-6
	if type(self.value) ~= "number" then fail("toBeCloseTo 需要数字") end
	if math.abs(self.value - expected) > t then
		fail(string.format("期望接近 %s（容差 %s），实际 %s", tostring(expected), tostring(t), tostring(self.value)))
	end
end

function harness.expect(value)
	return setmetatable({ value = value }, expectValue)
end

-- 返回汇总而不是退出。调用方（MCP）自己判断 failed 是否为 0。
function harness.run()
	local passed, failures = 0, {}
	for _, suite in ipairs(suites) do
		for _, case in ipairs(suite.cases) do
			local ok, err = pcall(case.fn)
			if ok then
				passed += 1
			else
				table.insert(failures, string.format("%s > %s — %s", suite.name, case.name, tostring(err)))
			end
		end
	end
	return {
		passed = passed,
		failed = #failures,
		total = passed + #failures,
		failures = failures,
	}
end

return harness
