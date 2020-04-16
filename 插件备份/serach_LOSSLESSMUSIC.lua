local curl = require "lcurl.safe"
local json = require "cjson.safe"


script_info = {
	["title"] = "LOSSLESS MUSIC",
	["version"] = "0.0.1",
	["description"] = "https://www.sq688.com/",
}

function request(args)

	local cookie = args.cookie or ""
	--pd.logInfo("the cccc..:"..cookie)
	local header = args.header or {"User-Agent: Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36"}
	--pd.logInfo("header cookie:"..header[2])
	local method = args.method or "GET"
	local para = args.para
	local url = args.url
	local data = ""
	if cookie then
		--pd.logInfo("set header cookie:".."Cookie: "..cookie)
		table.insert(header,"Cookie: "..cookie)
		--pd.logInfo("the header is:"..header[2])
	end
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
	local url = "https://www.sq688.com/search.php?key="..pd.urlEncode(key).."&page="..page

	local result = {}
	local start = 1
	local p_start,p_end,title,href,singer,songstype,fileSize,time
	local data = request({url=url})
	while true do
		p_start,p_end,href,title,singer,songstype,fileSize,time=string.find(data,' <tr>.-<a href="(.-)" .->(.-)</a></td>.-<td><a.->(.-)</a></td>.-class="songstype">(.-)</span></td>.-<td>(.-)</td>.-<td>(%d%d%d%d%-%d%d%-%d%d)</td>',start)

		if not href then
			break
		end

		--pd.logInfo("href:"..href)
		--pd.logInfo("title:"..title)
		--pd.logInfo("singer:"..singer)
		--pd.logInfo("songstype:"..songstype)
		--pd.logInfo("fileSize:"..fileSize)
		--pd.logInfo("time:"..time)


		href = "https://www.sq688.com"..href

		local tooltip = string.gsub(title, key, "%1")
			title = string.gsub(title,key, "{c #ff0000}%1{/c}")
			local description = "歌手："..singer.."  文件大小："..fileSize.."  文件格式："..songstype
			table.insert(result,{["href"]=href, ["title"]=title, ["time"]=time, ["showhtml"] = "true", ["tooltip"] = tooltip, ["check_url"] = "true",["description"] = description})

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
	--pd.logInfo("data:"..data)
	local p_start,p_end,baiduPan_url,password = string.find(data,'<input id="path".-value="(.-)" />.-data%-clipboard%-text="(.-)">')
	if password then
		baiduPan_url = baiduPan_url .. " " .. password
	end
	--pd.logInfo("baiduPan_url:"..baiduPan_url)
	return baiduPan_url
end

