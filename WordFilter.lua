--
-- Author: wishes2018
-- Date: 2017-11-01 17:35:59
-- letter 字母 不够成独立的意思
-- word 字 构成独立的意思
local WordFilter = class("WordFilter")

function WordFilter:ctor(replaceWord,ignoreWords,maxDepth)
	ignoreWords = ignoreWords or ""
	self.maxDepth = maxDepth or 20   --最大深度，暂未处理
	self.firstLevel = {_isInit=false,_isEnd=false,iters={},map={}}
	self.ignoreCode = {}


	for i,code in utf8.codes(ignoreWords) do
		self.ignoreCode[code] = true
	end

	self.replaceCode = utf8.codepoint(replaceWord)
end

function WordFilter:init(list)
	for k,words in pairs(list) do
		local iter = {}
		iter._f,iter._s,iter._var = utf8.codes(words)
		local code = self:next(iter)
		if code then
			if not self.firstLevel.map[code] then
				local nextLevel = {_isInit=false,_isEnd=false,iters={},map={}}
				self.firstLevel.map[code] = nextLevel
			end
			table.insert(self.firstLevel.map[code].iters,iter)
		end
	end
	self.firstLevel._isInit = true
end

function WordFilter:unfoldLevel(level,isAdd)
	--已经解析完成，直接返回
	if level._isInit and not isAdd then
		return
	end

	--解析该层，生成下一层
	for i,iter in ipairs(level.iters) do
		local code = self:next(iter)
		if code then
			if not level.map[code] then
				local nextLevel = {_isInit=false,_isEnd=false,iters={},map={}}
				level.map[code] = nextLevel
				print("----unfold ",utf8.char(code))
			end
			table.insert(level.map[code].iters,iter)
		else
			level._isEnd = true
		end
	end
	level._isInit = true
	level.iters = {} --该层解析完成，清空
end


function WordFilter:doFilter(words)
	local ret = {}
	local replaceList = {}
	local startIndex = 0
	local endIndex = 0
	local currLevel = self.firstLevel
	local nextLevel = currLevel
	local i = 0


	local insertReplace = function() 
		if startIndex == 0 then
			startIndex = i
		end

		self:unfoldLevel(nextLevel)
		currLevel = nextLevel

		if nextLevel._isEnd then
			endIndex = i
			if startIndex > 0 and endIndex > 0 and endIndex >= startIndex then
				table.insert(replaceList,{startIndex,endIndex})
			end
			--屏蔽词完结,重置成第一层
			currLevel = self.firstLevel
			startIndex = 0
			endIndex = 0
		end
	end


	for index,code in utf8.codes(words) do
		table.insert(ret,code)
		i = #ret

		if not self.ignoreCode[code] then
			code = self:convertEnLowerCode(code)
			nextLevel = currLevel and currLevel.map[code]

			if nextLevel then
				insertReplace()
			else
				--重置成第一层
				currLevel = self.firstLevel
				startIndex = 0
				endIndex = 0

				--重置成第一层后再检查一次该字，即以该字为屏蔽词首字
				nextLevel = currLevel and currLevel.map[code]
				if nextLevel then
					insertReplace()
				end
			end
			print("----------doFilter ",code,utf8.char(code),nextLevel and nextLevel._isEnd)
		end
	end

	-- dump(self.firstLevel,"self.firstLevel",10)
	-- dump(replaceList,"replaceList",10)

	if #replaceList > 0 then
		for i,replace in ipairs(replaceList) do
			if self:isLetter(ret[replace[2]]) then
				local needReplace = true
				local nextLetter = ret[replace[2] + 1]
				local preLetter = ret[replace[1] - 1]
				if self:isLetter(nextLetter) or self:isLetter(preLetter) then
					needReplace = false
				end

				local nextReplace = replaceList[i+1]
				if nextReplace and nextReplace[1] == (replace[2] + 1) then
					needReplace = true
				end
	
				if  needReplace then
					for j=replace[1],replace[2] do
						ret[j] = self.replaceCode
					end
				end
			else
				--不是字母，直接执行替换
				for j=replace[1],replace[2] do
					ret[j] = self.replaceCode
				end
			end
		end
		return utf8.char(table.unpack(ret))
	else
		return nil
	end
end



function WordFilter:isFilter(words)
	local ret = {}
	local replaceList = {}
	local startIndex = 0
	local endIndex = 0
	local currLevel = self.firstLevel
	local nextLevel = currLevel
	local i = 0

	local checkFilter = function()
		if startIndex == 0 then
			startIndex = i
		end

		self:unfoldLevel(nextLevel)
		currLevel = nextLevel

		if nextLevel._isEnd then
			endIndex = i
			if startIndex > 0 and endIndex > 0 and endIndex >= startIndex then
				table.insert(replaceList,{startIndex,endIndex})
				--非字母直接确认为屏蔽词，返回
				if not self:isLetter(ret[endIndex]) then
					return true
				end
			end
			--屏蔽词完结,重置成第一层
			currLevel = self.firstLevel
			startIndex = 0
			endIndex = 0
		end
	end

	for index,code in utf8.codes(words) do
		table.insert(ret,code)
		i = #ret

		if not self.ignoreCode[code] then
			code = self:convertEnLowerCode(code)
			nextLevel = currLevel and currLevel.map[code]
			if nextLevel then
				if checkFilter() then
					return true
				end
			else
				--重置成第一层
				currLevel = self.firstLevel
				startIndex = 0
				endIndex = 0

				--重置成第一层后再检查一次该字
				nextLevel = currLevel and currLevel.map[code]
				if nextLevel then
					if checkFilter() then
						return true
					end
				end
			end
		end
	end

	-- dump(self.firstLevel,"self.firstLevel",10)
	-- dump(replaceList,"replaceList",10)

	for i,replace in ipairs(replaceList) do
		if self:isLetter(ret[replace[2]]) then
			local needReplace = true
			local nextLetter = ret[replace[2] + 1]
			local preLetter = ret[replace[1] - 1]
			if self:isLetter(nextLetter) or self:isLetter(preLetter) then
				needReplace = false
			end

			local nextReplace = replaceList[i+1]
			if nextReplace and nextReplace[1] == (replace[2] + 1) then
				needReplace = true
			end
			return needReplace
		else
			return true
		end
	end
	return false
end

function WordFilter:next(iter)
	local k,v = iter._f(iter._s,iter._var)
	iter._var = k
	return v
end

function WordFilter:isLetter(code)
	if not code then
		return false
	end

	local letterArea = {65,90,97,122,126,687,880,1791,3584,3711}
	local len = #letterArea
	for i=1,len,2 do
		if code >= letterArea[i] and code <= letterArea[i+1] then
			return true
		end
	end

	return false
end

function WordFilter:convertEnLowerCode(code)
	if code >= 65 and code <=90 then
		return code + 32
	end
	return code
end


function WordFilter:addFilterWord(words)
	if not words then
		return
	end
	--第一层增加屏蔽词
	self:init({words})

	local currLevel = self.firstLevel
	local nextLevel = currLevel
	--展开其他层
	for index,code in utf8.codes(words) do
		if not self.ignoreCode[code] then
			code = self:convertEnLowerCode(code)
			nextLevel = currLevel and currLevel.map[code]
			if nextLevel then
				self:unfoldLevel(nextLevel,true) --对于已经展开过的，强制再展开一遍
				currLevel = nextLevel
			end
		end
	end
end

--删除屏蔽词，直接删掉最后一层(理论上可以向前回溯，进行删除剪枝，暂不这么做)
function WordFilter:delFilterWord(words)
	if not words then
		return
	end

	local currLevel = self.firstLevel
	local nextLevel = currLevel
	local notFind = false

	for index,code in utf8.codes(words) do
		if not self.ignoreCode[code] then
			code = self:convertEnLowerCode(code)
			nextLevel = currLevel and currLevel.map[code]
			if nextLevel then
				self:unfoldLevel(nextLevel) --被删除的该词，可能还未展开，先展开下
				currLevel = nextLevel
			else
				notFind = true
			end
		end
	end

	if notFind then
		print("----------not find del words",words)
	else
		nextLevel._isEnd = false --删除最后一层
	end
end

return WordFilter