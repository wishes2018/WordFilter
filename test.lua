--
-- Author: wishes2018
-- Date: 2017-11-15 02:23:17
--
require("init")
local worldFilter = require("WordFilter").new("+")
local list = {"fuck","操你妈","fucy","操你祖宗"}
worldFilter:init(list)
local result = worldFilter:doFilter("fucky ou mother f u c  *kb 测 试 屏 蔽 字")
print("result = ",result)