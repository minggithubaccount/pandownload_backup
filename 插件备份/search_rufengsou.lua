local curl = require "lcurl.safe"

script_info = {
	["title"] = "如风搜",
	["description"] = "http://www.rufengso.net/",
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


function onSearch(key, page)

	local data =  request("http://www.rufengso.net/s/name/" .. pd.urlEncode(key) .. "/" .. page)
	local result = {}
	local start = 1

	while true do

		local start_position, end_position, title, href = string.find(data,"<div class=\"row\".-title=\"(.-)\" href=\"(.-)\">",start)

		if href == nil then
			break
		end
		href = "http://www.rufengso.net" .. href
		table.insert(result,{["title"]=title,["href"]=href})
		start = end_position + 1
	end

	return result

end

function onItemClick(item)

	local url = exRequest(item.href)
	if url == nil then
		return ACT_MESSAGE, '获取URL失败'
	end

	return ACT_SHARELINK, url

end

function exRequest(url)
	local ret = request(url)
	local _, __, href = string.find(ret,'class="dbutton2" href="(.-)"',1)

	ret = request(href)
	_,__,url = string.find(ret, "URL='(.-)'")
	return url
end
