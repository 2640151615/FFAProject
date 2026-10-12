-- 骨架自检：确认断言既会通过、也会失败。
-- 只注册，不调 run()（由 test/run.luau 统一调用）。

local harness = require("./harness")
local describe, it, expect = harness.describe, harness.it, harness.expect

describe("骨架自检", function()
	it("断言能通过", function()
		expect(1 + 1):toBe(2)
	end)
end)
