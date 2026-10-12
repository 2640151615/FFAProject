-- 测试入口。加载 test/ 下所有 *.spec.luau，然后统一跑一次。
-- 必须在工程根目录执行：lune run test/run.luau
-- （fs 是相对当前工作目录的，不是相对本文件）

local fs = require("@lune/fs")
local harness = require("./harness")

for _, name in ipairs(fs.readDir("test")) do
	if name:match("%.spec%.luau$") then
		require("./" .. name:gsub("%.luau$", ""))
	end
end

harness.run()
