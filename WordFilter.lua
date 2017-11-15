--
-- Author: wishes2018
-- Date: 2017-11-01 17:35:59
-- letter 字母 不够成独立的意思
-- word 字 构成独立的意思
local WordFilter = class("WordFilter")

function WordFilter:ctor(replaceWord,ignoreWords,maxDepth)
	ignoreWords = ignoreWords or ""
	self.maxDepth = maxDepth or 20   --最大深度，暂未处理
	self.firstLevel = {_isInit=false,iters={},map={}}
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
		if not self.firstLevel.map[code] then
			local nextLevel = {_isInit=false,iters={},map={}}
			self.firstLevel.map[code] = nextLevel
		end
		table.insert(self.firstLevel.map[code].iters,iter)
	end
	self.firstLevel._isInit = true
end

function WordFilter:unfoldLevel(level)
	if level._isInit then
		return
	end

	 for i,iter in ipairs(level.iters) do
	 	local code = self:next(iter)
	 	if code then
			if not level.map[code] then
				local nextLevel = {_isInit=false,iters={},map={}}
				level.map[code] = nextLevel
			end
			table.insert(level.map[code].iters,iter)
	 	end
	 end
	 level._isInit = true
end

function WordFilter:doFilter(words)
	local ret = {}
	local replaceList = {}
	local startIndex = 0
	local endIndex = 0
	local currLevel = self.firstLevel
	local isExist = false

	for i,code in utf8.codes(words) do
		if not self.ignoreCode[code] then
			local nextLevel = currLevel and currLevel.map[code]
			if nextLevel then
				if startIndex == 0 then
					startIndex = i
				end
				endIndex = i
				self:unfoldLevel(nextLevel)
				currLevel = nextLevel
			else
				if startIndex > 0 and endIndex > 0 and endIndex > startIndex then
					table.insert(replaceList,{startIndex,endIndex})
				end

				--重置成第一层
				currLevel = self.firstLevel
				startIndex = 0
				endIndex = 0

				--重置成第一层后再检查一次该字
				nextLevel = currLevel and currLevel.map[code]
				if nextLevel then
					if startIndex == 0 then
						startIndex = i
					end
					endIndex = i
					self:unfoldLevel(nextLevel)
					currLevel = nextLevel
				end
			end
		end

		table.insert(ret,code)
	end

	if startIndex > 0 and endIndex > 0 and endIndex > startIndex then
		table.insert(replaceList,{startIndex,endIndex})
	end


	-- dump(self.firstLevel,"self.firstLevel",10)
	-- dump(replaceList,"replaceList",10)

	if #replaceList > 0 then
		for i,replace in ipairs(replaceList) do
			if self:isLetter(ret[replace[1]]) and self:isLetter(ret[replace[2]]) then
				local preLetter = ret[replace[1] - 1]
				local nextLetter = ret[replace[2] + 1]
				--前后两个都不是字母时，执行替换				
				if not self:isLetter(preLetter) and not self:isLetter(nextLetter) then
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
	local isExist = false

	for i,code in utf8.codes(words) do
		if not self.ignoreCode[code] then
			local nextLevel = currLevel and currLevel.map[code]
			if nextLevel then
				if startIndex == 0 then
					startIndex = i
				end
				endIndex = i
				self:unfoldLevel(nextLevel)
				currLevel = nextLevel
			else
				if startIndex > 0 and endIndex > 0 and endIndex > startIndex then
					if self:isLetter(ret[startIndex]) and self:isLetter(ret[endIndex]) then
						local preLetter = ret[startIndex - 1]
						local nextLetter = ret[endIndex + 1]
						--前后两个都不是字母时为屏蔽字
						if not self:isLetter(preLetter) and not self:isLetter(nextLetter) then
							return true
						end
						return false
					end

					return true
				end

				--重置成第一层
				currLevel = self.firstLevel
				startIndex = 0
				endIndex = 0

				--重置成第一层后再检查一次该字
				nextLevel = currLevel and currLevel.map[code]
				if nextLevel then
					if startIndex == 0 then
						startIndex = i
					end
					endIndex = i
					self:unfoldLevel(nextLevel)
					currLevel = nextLevel
				end
			end
		end

		table.insert(ret,code)
	end

	if startIndex > 0 and endIndex > 0 and endIndex > startIndex then
		if self:isLetter(ret[startIndex]) and self:isLetter(ret[endIndex]) then
			local preLetter = ret[startIndex - 1]
			local nextLetter = ret[endIndex + 1]
			--前后两个都不是字母时为屏蔽字
			if not self:isLetter(preLetter) and not self:isLetter(nextLetter) then
				return true
			end
			return false
		end
		return true
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

	if code >= 65 and code <=90 or code >= 97 and code <= 122 then
		return true
	end
end

return WordFilter