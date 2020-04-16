local curl = require "lcurl.safe"

script_info = {
	["title"] = "猪猪盘",
	["description"] = "http://www.zhuzhupan.com/",
	["version"] = "0.0.1",
}

function onSearch(key, page)
	if page == 1 then
		return parse(get("http://www.zhuzhupan.com/search?s=1&query=" .. pd.urlEncode(key)))
	else
		return {}
	end
end

function onItemClick(item)
	local act = ACT_SHARELINK
	local _, _, arg = string.find(get(item.url), "(https?://pan.baidu.com/s/[A-Za-z0-9-_]+)")
	if arg == nil or #arg == 0 then
		act = ACT_ERROR
		arg = "获取链接失败"
	end
	return act, arg 
end

function get(url)
	local r = ""
	local c = curl.easy{
		url = url,
		followlocation = 1,
		timeout = 15,
		cookie = "is_ps2=SUCCESS",
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

function parse(data)
	local result = {}
	local start = 1
	while true do
		local a, b, url, title, time = string.find(data, "href=\"(/gotopan_pay%?.-)\".-_blank\">(.-)</a>.-分享时间：(%d%d%d%d%-%d%d%-%d%d)", start)
		if url == nil then
			break
		end
		local tooltip = string.gsub(title, "<font color=\"#c00\">(.-)</font>", "%1")
		title = string.gsub(title, "<font color=\"#c00\">(.-)</font>", "{c #ff0000}%1{/c}")
		table.insert(result, {["url"] = "http://www.zhuzhupan.com" .. url, ["title"] = title, ["time"] = time, ["showhtml"] = "true", ["tooltip"] = tooltip})
		start = b + 1
	end
	return result
end