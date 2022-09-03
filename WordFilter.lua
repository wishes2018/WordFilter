--
-- Author: wishes2018
-- Date: 2017-11-01 17:35:59
-- letter 字母 不够成独立的意思
-- word 字 构成独立的意思
local WordFilter = class("WordFilter")

function WordFilter:ctor(replaceWord,ignoreWords,handleLetter,maxDepth)
	ignoreWords = ignoreWords or ""
	self.maxDepth = maxDepth or 20   --最大深度，暂未处理
	self.firstLevel = {_isInit=false,_isEnd=false,iters={},map={}}
	self.ignoreCode = {}
	self.handleLetter = true --是否处理字母
	if handleLetter ~= nil then
		self.handleLetter = handleLetter
	end

	for i,code in utf8.codes(ignoreWords) do
		self.ignoreCode[code] = true
	end

	self.replaceCode = utf8.codepoint(replaceWord)
end

function WordFilter:init(list)
	for k,words in pairs(list) do
		local iter = {}
		iter._f,iter._s,iter._var = utf8.codes(words)
		local code = self:nextCode(iter)
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
	if not level then
		return
	end
	--已经解析完成，直接返回
	if level._isInit and not isAdd then
		return
	end

	--解析该层，生成下一层
	for i,iter in ipairs(level.iters) do
		local code = self:nextCode(iter)
		if code then
			if not level.map[code] then
				local nextLevel = {_isInit=false,_isEnd=false,iters={},map={}}
				level.map[code] = nextLevel
				-- print("----unfold ",utf8.char(code))
			end
			table.insert(level.map[code].iters,iter)
		else
			level._isEnd = true
		end
	end
	level._isInit = true
	level.iters = {} --该层解析完成，清空
end


--对字母需要判断前后
function WordFilter:replaceLetters(codeList,codeLen,beginIndex,endIndex,level)
	--该词前面为字母,不为屏蔽词
	if self:isLetter(codeList[beginIndex - 1]) then
		print("----该词前面为字母,不为屏蔽词")
		return nil
	end

	--多个屏蔽词相连，不用处理.由于前一个屏蔽词已被替换成*,*不为字母

	--该词继续往后拓
	local currentLevel = level
	local nextLevel = nil
	local code = nil
	local hasNewLetter = false
	for i=endIndex+1,codeLen do
		code = self:convertEnLowerCode(codeList[i])
		if self:isLetter(code) and currentLevel then
			hasNewLetter = true
			nextLevel = currentLevel.map[code]
			currentLevel = nextLevel
			self:unfoldLevel(nextLevel)
			print("--------letter code ",utf8.char(code),nextLevel and nextLevel._isEnd)
			if nextLevel and nextLevel._isEnd then
				print("----该词后面为字母,并构成新屏蔽词",beginIndex,i)
				return beginIndex,i
			end
		else
			break
		end
	end

	if hasNewLetter then
		print("----该词后面为字母，且组成单词不为屏蔽词")
		return nil
	end

	return beginIndex,endIndex
end

function WordFilter:findReplace(codeList,index)
	print("--------BeginFind")
	local currentLevel = self.firstLevel
	local nextLevel = nil
	local beginIndex = nil
	local len = #codeList
	for i=index,len do
		local code = codeList[i]
		if not self.ignoreCode[code] then
			code = self:convertEnLowerCode(code)
			if not beginIndex then
				beginIndex = i
			end
			nextLevel = currentLevel.map[code]
			self:unfoldLevel(nextLevel)
			print("--------code ",utf8.char(code),nextLevel and nextLevel._isEnd)
			if nextLevel then
				if nextLevel._isEnd then
					print("--------replace ",beginIndex,i)
					if self:isLetter(codeList[i]) then
						return self:replaceLetters(codeList,len,beginIndex,i,nextLevel)
					end
					--找到则结束，否则继续遍历
					return beginIndex,i
				end
				currentLevel = nextLevel
			else
				return nil
			end
		end
	end
end

function WordFilter:doFilter(words)
	if not words then return nil end
	local codeList = table.pack(utf8.codepoint(words,1,#words))
	local beReplaced = false
	local codeBegin = 1
	local len = #codeList

	while codeBegin <= len do
		if not self.ignoreCode[codeList[codeBegin]] then
			local replaceBegin,replaceEnd = self:findReplace(codeList,codeBegin)
			if replaceEnd then
				codeBegin = replaceEnd
				beReplaced = true
				for i=replaceBegin,replaceEnd do
					codeList[i] = self.replaceCode
				end
			end
		end
		codeBegin = codeBegin + 1
	end

	if beReplaced then
		return utf8.char(table.unpack(codeList))
	else
		return nil
	end
end

function WordFilter:isFilter(words)
	if not words then return false end
	local codeList = table.pack(utf8.codepoint(words,1,#words))
	local codeBegin = 1
	local len = #codeList

	while codeBegin <= len do
		if not self.ignoreCode[codeList[codeBegin]] then
			local replaceBegin,replaceEnd = self:findReplace(codeList,codeBegin)
			if replaceEnd then
				return true
			end
		end
		codeBegin = codeBegin + 1
	end
end

function WordFilter:nextCode(iter)
	local k,v = iter._f(iter._s,iter._var)
	if k then
		iter._var = k
	end
	return v
end

function WordFilter:isLetter(code)
	if not code then
		return false
	end

	if not self.handleLetter then
		return false
	end

	local letterArea = {65,90,97,122,192,687,880,1791,3584,3711}
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