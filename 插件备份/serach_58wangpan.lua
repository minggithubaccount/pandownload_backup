local curl = require "lcurl.safe"
local json = require "cjson.safe"


script_info = {
	["title"] = "58网盘",
	["version"] = "0.0.1",
	["description"] = "https://www.58wangpan.com/",
}

function request(args)

	local cookie = args.cookie or ""
	local referer = args.referer or ""
	--pd.logInfo("the cccc..:"..cookie)
	local header = args.header or {"User-Agent: Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36","Cookie: "..cookie,"Referer: "..referer}
	--pd.logInfo("header cookie:"..header[2])
	local method = args.method or "GET"
	local para = args.para
	local url = args.url
	local data = ""

	local c = curl.easy{
		url = url,
		ssl_verifyhost = 0,
		ssl_verifypeer = 0,
		timeout = 15,
		proxy = pd.getProxy(),
	}


	if para ~= nil then
		c:setopt(curl.OPT_POST, 1)
		c:setopt(curl.OPT_POSTFIELDS, para)
	end

	if header ~= nil then
		c:setopt(curl.OPT_HTTPHEADER, header)
	end

	if method == "HEAD" then
		c:setopt(curl.OPT_NOBODY, 1)
		--c:setopt(curl.OPT_FOLLOWLOCATION, 1)
		c:setopt(curl.OPT_HEADERFUNCTION, function(h)
			data = data .. h
		end)
	else
		c:setopt(curl.OPT_WRITEFUNCTION, function(buffer)
			data = data .. buffer
			return #buffer
		end)
	end

	local _, err = c:perform()
	if err == nil and method == "HEAD" then
		--data = c:getinfo(curl.INFO_EFFECTIVE_URL)
	end
	c:close()

	if err then
		return nil, tostring(err)
	else
		return data, nil
	end



end

function onSearch(key,page)
	local url = "https://www.58wangpan.com/search/o1kw"..pd.urlEncode(key).."pg"..page

	local result = {}
	local start = 1
	local p_start,p_end,title,href,fileType,time
	local data = request({url=url})
	while true do
		p_start,p_end,fileType,href,title,time=string.find(data,'<i class="file%-icon i(.-)"></i>.-<div class="title"><a href="(.-)" title=".-" target="_blank" >(.-)</a></div>.-<div class="feed_time"><span>(.-)</span></div>',start)

		if not href then
			pd.logInfo("no href:..")
			break
		end

		--pd.logInfo("href:"..href)
		--pd.logInfo("title:"..title)
		--pd.logInfo("singer:"..singer)
		--pd.logInfo("songstype:"..songstype)
		--pd.logInfo("fileSize:"..fileSize)
		--pd.logInfo("time:"..time)


		href = "https://www.58wangpan.com"..href
		--local img = "https://www.58wangpan.com/images/"..fileType..".png"
		local tooltip = string.gsub(title, '<font color="red" >(.-)</font>', "%1")
		title = string.gsub(title,'<font color="red" >(.-)</font>', "{c #ff0000}%1{/c}")
		pd.logInfo("title:.."..title)
		table.insert(result,{["href"]=href, ["title"]=title, ["time"]=time, ["showhtml"] = "true", ["tooltip"] = tooltip, ["fileType"] = fileType})

		start = p_end + 1

	end

	return result
end

function onItemClick(item)
	local url = getUrl(item.href)
	if url then
		return ACT_SHARELINK,url
	else
		return ACT_ERROR,"获取链接失败"
	end

end

function getUrl(href)
	local data = request({url=href})
	local baiduPan_url,url
	--pd.logInfo("data:"..data)
	local p_start,p_end,fileID = string.find(data,"dialog_fileId = '(.-)'")
	if fileID then
		url = "https://www.58wangpan.com/redirect/file?id="..fileID
		data = request({url=url,referer=href})
		p_start,p_end,baiduPan_url = string.find(data,"var url = '(.-)'")
	end
	--pd.logInfo("baiduPan_url:"..baiduPan_url)
	return baiduPan_url
end

