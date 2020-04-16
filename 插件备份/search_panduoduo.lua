local curl = require "lcurl.safe"

script_info = {
	["title"] = "盘多多",
	["description"] = "http://www.panduoduo.net/",
	["version"] = "0.0.1",
}

function onSearch(key, page)
	return parse(get("http://www.panduoduo.net/s/comb/n-" .. urlEncode(key) .. "&s-feedtime1&ty-bd/" .. page))
end

function onItemClick(item)
	local act = ACT_SHARELINK
	local _, _, arg = string.find(get(item.url), "<a href=\"(.-)\"")
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
		proxy = pd.getProxy(),
		writefunction = function(buffer)
			r = r .. buffer
			return #buffer
		end,
	}
	c:perform()
	c:close()
	return r
end

function parse(data)
	local result = {}
	local start = 1
	while true do
		local a, b, title, id = string.find(data, "<a target=\"_blank\" title=\"(.-)\" href=\"/r/(%d+)\"", start)
		if id == nil then
			break
		end
		table.insert(result, {["url"] = "http://pdd.19mi.net/go/" .. id, ["title"] = title})
		start = b + 1
	end
	return result
end

function urlEncode(s)
	return (string.gsub(
		s,
		"[^%w%-_%.!~%*'%(%)]",
		function(c)
			return string.format("%%%02X", string.byte(c))
		end
	))
end