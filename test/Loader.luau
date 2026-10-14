-- 被测模块的加载器：按当前 Source 新建实例再 require，绕开 Roblox 的 require 缓存。
--
-- 和 TestKit.load 的唯一区别：会同时搜 ReplicatedStorage 与 StarterPlayerScripts。
-- 客户端模块（Recoil / AimAssist）同步到 StarterPlayerScripts 下，同样需要单测。
--
-- 为什么单独一个文件、而不是并进 TestKit：
--   TestKit 已经被 require 过，它的缓存在本次 Studio 会话里是冻的——
--   改它不会生效（实测：源码改成 v2 了，require 仍返回 v1）。新模块才有干净的第一份。
--
-- 复制品放在原模块的**同一父级**下，这样模块内部的相对 require 才能解析到同一批兄弟模块。

local CONTAINERS = {
	game:GetService("ReplicatedStorage"),
	game:GetService("StarterPlayer"),
}

local function findModule(name)
	for _, container in ipairs(CONTAINERS) do
		if container then
			local direct = container:FindFirstChild(name)
			if direct and direct:IsA("ModuleScript") then
				return direct
			end
			-- StarterPlayerScripts 下的客户端模块
			local scripts = container:FindFirstChild("StarterPlayerScripts")
			local nested = scripts and scripts:FindFirstChild(name)
			if nested and nested:IsA("ModuleScript") then
				return nested
			end
		end
	end
	return nil
end

return function(name)
	local original = findModule(name)
	assert(original ~= nil, "找不到模块: " .. tostring(name))

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
