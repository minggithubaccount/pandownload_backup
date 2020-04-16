local curl = require "lcurl.safe"

script_info = {
	["title"] = "BD影视",
	["description"] = "https://www.bd-film.cc/",
	["version"] = "0.0.1",
}

function request(url)
	local r = ""
	local c = curl.easy{
		url = url,
		httpheader = {
			"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.86 Safari/537.36",
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

function onSearch(keyword, page)
	local data = request("https://www.bd-film.cc/search_"..page..".jspx?q="..pd.urlEncode(keyword))
	local result = {}
	local start = 1
	while true do
		local _, b, img, url, title, description = string.find(data, '<img src="(.-)".-<a href="(.-)" title=.->(.-)</a>.-<div.->(.-)</div>', start)
		if url == nil then
			break
		end
		description = string.gsub(description, "^%s*(.-)%s*$", "%1", 1)
		table.insert(result, {["url"] = url, ["title"] = pd.htmlUnescape(title), ["image"] = img, ["icon_size"] = "47,67", ["description"] = description})
		start = b + 1
	end
	return result
end

function onItemClick(item)
	local act = ACT_SHARELINK
	local arg, pwd = "", ""
	_, _, arg = string.find(request(item.url), 'diskUrls = "([^"]+)')
	if arg then
		arg = pd.base64Decode(string.reverse(arg))
		_, _, pwd, arg = string.find(arg, "(.-)||(.+)")
		if pwd then
			arg = arg.." "..pwd
		end
	end
	if arg == nil then
		act = ACT_ERROR
		arg = "获取资源失败"
	end
	return act, arg 
end