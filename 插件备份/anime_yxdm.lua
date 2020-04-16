local curl = require "lcurl.safe"
local json = require "cjson.safe"

script_info = {
	["title"] = "怡萱动漫",
	["description"] = "http://www.yxdm.tv/",
	["version"] = "0.0.1",
}

function request(url)
	local r = ""
	local c = curl.easy{
		url = url,
		httpheader = {
			"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.86 Safari/537.36",
			"Referer: http://www.yxdm.tv/",
		},
		ssl_verifyhost = 0,
		ssl_verifypeer = 0,
		followlocation = 1,
		timeout = 15,
		proxy = pd.getProxy(),
		writefunction = function(buffer)
			r = r .. buffer
			return #buffer
		end,
	}
	local _, e = c:perform()
	c:close()
	return r
end

function onInitAnime()
	local data = request("http://www.yxdm.tv/")
	local anime_week = {}
	local week = {"星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"}
	local sep = {"weektbc_01", "weektbc_02", "weektbc_03", "weektbc_04", "weektbc_05", "weektbc_06", "weektbc_07", "</ul>"}
	for i = 1, 7 do
		local _, _, tmp = string.find(data, sep[i].."(.-)"..sep[i+1])
		local begin = 1
		local anime_day = {["title"] = week[i]}
		while tmp do
			local _, b, name, id = string.find(tmp, '<A title="(.-)" href="/resource/(%d+).html"', begin)
			if id == nil then
				break
			end
			table.insert(anime_day, {["url"] = "http://www.yxdm.tv/getdlist.php?id="..id, ["name"] = name})
			begin = b + 1
		end
		table.insert(anime_week, anime_day)
	end
	return anime_week
end

function onSearch(keyword, page)
	local data = request("http://www.yxdm.tv/search.html?keyword="..pd.urlEncode(keyword).."&searchtype=titlekeyword&channeltype=0&orderby=&kwtype=0&pagesize=18&typeid=0&PageNo="..page)
	local result = {}
	local start = 1
	while true do
		local _, b, title, id, img, desc, time = string.find(data, '<p><a title="([^"]+)" href="/resource/(%d+).html" target="_blank"><img src="(.-)">.-更新至：.->([^<>]+)</a>.-日期：.->([^<]+)</', start)
		if id == nil then
			break
		end
		if #img > 0 and string.byte(img) == 47 then
			img = "http://www.yxdm.tv"..img
		end
		table.insert(result, {["url"] = "http://www.yxdm.tv/getdlist.php?id="..id, ["title"] = pd.htmlUnescape(title), ["image"] = img, ["icon_size"] = "50,67", ["time"] = time, ["description"] = "更新至："..desc})
		start = b + 1
	end
	return result
end

function onItemClick(item)
	local j = json.decode(request(item.url))
	if j == nil or j.data == nil or #j.data == 0 or j.data[1].list == nil or #j.data[1].list == 0 or j.data[1].list[1].url == nil or #j.data[1].list[1].url == 0 then
		return ACT_ERROR, "获取资源失败"
	end
	return ACT_SHARELINK, pd.base64Decode(j.data[1].list[1].url)
end