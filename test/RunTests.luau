-- 测试入口。经 Rojo 同步到 ServerStorage.__tests.RunTests。
--
-- 跑法（MCP execute_luau，edit 模式即可）：
--   return require(game:GetService("ServerStorage").__tests.RunTests)
-- 返回 { passed, failed, total, failures, loadErrors }。
--
-- 每个 spec 的 require 都包在 pcall 里。这不是为了掩盖 spec 的错误，而是因为
-- Studio edit 模式下**改 Source 不会让 require 缓存失效**：某个 spec 一旦以坏的
-- 状态被 require 过，那个错误就会被永久缓存在该实例上，怎么改都还是旧错误。
-- 包了 pcall，坏掉的 spec 只记进 loadErrors，不会连带把本模块的 require 一起毒化。
-- 换新实例（改文件名）才是清除缓存的办法。
--
-- 新增 spec：在 test/specs/ 放一个**会返回值**的 ModuleScript，自动收录。

local harness = require(script.Parent.harness)

local loadErrors = {}
for _, spec in ipairs(script.Parent.specs:GetChildren()) do
	if spec:IsA("ModuleScript") then
		local ok, err = pcall(require, spec)
		if not ok then
			table.insert(loadErrors, spec.Name .. " — " .. tostring(err))
		end
	end
end

local result = harness.run()
result.loadErrors = loadErrors
return result
