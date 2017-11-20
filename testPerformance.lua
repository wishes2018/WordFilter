--
-- Author: wishes2018
-- Date: 2017-11-15 02:24:13
--
require("init")
local data = require("data")
local worldFilter = require("WordFilter").new("*","* -[]")

local socket = require("socket.core")

local beginTime = socket.gettime()
worldFilter:init(data)
local result = worldFilter:doFilter("fucky o mothers f u c  *k 测 试 屏 蔽 字")
local endTime = socket.gettime()

print("result = ",result)
print("-------first use time "..endTime-beginTime)

local beginTime = socket.gettime()
local result = worldFilter:doFilter("abfuck you fsff 我")
local endTime = socket.gettime()

print("result = ",result)
print("-------second use time "..endTime-beginTime)


local beginTime = socket.gettime()
local result = worldFilter:isFilter("abfuck you fsff 我")
local endTime = socket.gettime()

print("result = ",result)
print("-------second use time "..endTime-beginTime)

