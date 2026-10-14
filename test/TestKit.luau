-- 测试基建（Roblox 侧）。
--
-- 为什么需要 TestKit.load 而不是直接 require：
--   实测确认，Studio edit 模式下**改一个已经 require 过的 ModuleScript 源码，
--   require 缓存不会失效**——源码同步成 v2 了，require 仍返回 v1。
--   这会让 TDD 的"改实现看 GREEN"完全空转。
--   因此 load() 每次按当前 Source 重新构造一份实例再 require，强制拿到磁盘上的最新代码。
--
-- 由此推出两条纪律：
--   1. spec 只注册用例，由入口统一调一次 run()（本模块是单例，重复调会重复执行先前用例）。
--   2. spec 里的**被测共享模块**一律走 kit.load(...)，不要直接 require。
--      直接 require 一次之后就永远冻在那一刻的代码上。
--
-- 注意：本模块自身也是 ModuleScript，一旦被 require 就会被冻结。
-- 若需修改本文件，改完后必须换个新文件名才能生效（或重启 Studio）。

local TestKit = {}

local suites = {}
local currentSuite = nil

function TestKit.describe(name, fn)
	local suite = { name = name, cases = {} }
	-- 同名覆盖而非追加：反复调试时同一 spec 可能注册多次，不去重会重复计数。
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

function TestKit.it(name, fn)
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

function expectValue:toBeFalsy()
	if self.value then fail("期望假值，实际 " .. tostring(self.value)) end
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

function TestKit.expect(value)
	return setmetatable({ value = value }, expectValue)
end

-- 按当前 Source 重新构造实例再 require，绕开 Roblox 的 require 缓存。
-- 复制品放在**原模块的同一父级**下，这样模块内部的相对 require 才能解析到同一批兄弟模块。
function TestKit.load(name)
	local original = game:GetService("ReplicatedStorage"):FindFirstChild(name)
	assert(original ~= nil and original:IsA("ModuleScript"), "找不到共享模块: " .. tostring(name))

	local copy = Instance.new("ModuleScript")
	copy.Name = name .. "__fresh"
	copy.Source = original.Source
	copy.Parent = original.Parent

	local ok, result = pcall(require, copy)
	copy:Destroy()

	if not ok then
		error(string.format("加载 %s 失败: %s", name, tostring(result)), 2)
	end
	return result
end

-- 返回汇总而不是退出进程。
function TestKit.run()
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

-- 跑全部 spec 并返回汇总。
--
-- spec 同样**按当前 Source 重建实例再 require**，理由和 load() 一样：直接 require
-- 会让 spec 冻在被首次加载的那一刻，之后往 spec 里加用例根本不会生效。
-- 重建带来的重复注册由 describe 的同名覆盖消化，不会重复计数。
--
-- 每次调用都重新遍历 specs 目录，因此新增 spec 无需重启即可被收录。
function TestKit.runAll(specsFolder)
	local loadErrors = {}
	for _, spec in ipairs(specsFolder:GetChildren()) do
		if spec:IsA("ModuleScript") then
			local copy = Instance.new("ModuleScript")
			copy.Name = spec.Name .. "__fresh"
			copy.Source = spec.Source
			-- 放在 spec 目录下，spec 里的 script.Parent.Parent.TestKit 才能解析
			copy.Parent = specsFolder

			local ok, err = pcall(require, copy)
			copy:Destroy()

			if not ok then
				table.insert(loadErrors, spec.Name .. " — " .. tostring(err))
			end
		end
	end
	local result = TestKit.run()
	result.loadErrors = loadErrors
	return result
end

return TestKit
