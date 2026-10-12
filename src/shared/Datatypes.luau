-- Roblox 数据类型的薄桥。
--
-- Roblox 里 CFrame / Vector3 / Vector2 是全局。Lune 里**一个全局都没有**
-- （实测 Lune 0.10.5：这些全部为 nil，且 _G 赋值对外层不可见），
-- 必须从 @lune/roblox 取。
--
-- 需要跑单元测试的共享模块统一从这里取类型，而不是直接引用全局，
-- 这样同一份源码在 Roblox 与 Lune 下都能加载。
--
-- 引擎绑定、不参与单元测试的模块（服务、客户端）不必经这里，直接用全局即可。

local ok, luneRoblox = pcall(require, "@lune/roblox")

if ok and luneRoblox ~= nil then
	return {
		CFrame = luneRoblox.CFrame,
		Vector3 = luneRoblox.Vector3,
		Vector2 = luneRoblox.Vector2,
	}
end

return {
	CFrame = CFrame,
	Vector3 = Vector3,
	Vector2 = Vector2,
}
