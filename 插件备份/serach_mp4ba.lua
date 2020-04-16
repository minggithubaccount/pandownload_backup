local curl = require "lcurl.safe"

script_info = {
	["title"] = "MP4吧",
	["description"] = "http://www.mp4ba.com/",
	["version"] = "0.0.4",
}


function request(url,header)
	local r = ""
	local c = curl.easy{
		url = url,
		httpheader = header,
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
	local result = {}
	-- 搜索电视剧
	result = search_movie(key,page,"6",result)
	-- 搜索电影
	result = search_movie(key,page,"1",result)

	return result


end

function search_movie(key, page,modelid, result)
	local header = {
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.86 Safari/537.36",
	}
	local data = request("http://www.mp4ba.com/search/index/init/modelid/".. modelid .."/q/" .. pd.urlEncode(key) .. "/page/" .. page .. ".html" , header)
	local start = 1

	while true do

		local start_position, end_position, href, title,description, pub_time = string.find(data,'<div class="sousuo">.-<b><a href="(.-)" target="_blank">(.-)</a></b>.-target="_blank">(.-)</a></p>.-<span>(.-)</span>',start)

		if href == nil then
			break
		end

		local tooltip = string.gsub(title, "<span style='color:#f60;'>(.-)</span>", "%1")

		title = string.gsub(title, "<span style='color:#f60;'>(.-)</span>", "{c #ff0000}%1{/c}")

		description = string.gsub(description, "<span style='color:#f60;'>(.-)</span>", "%1")

		table.insert(result, {["href"] = href  , ["title"] = title,["showhtml"] = "true", ["tooltip"] = tooltip, ["time"] = pub_time, ["description"] = description })

		start = end_position + 1

	end

	return result
end

function onItemClick(item)

	local header = {
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.86 Safari/537.36",
	}

	local ret = request(item.href,header)

	local _, __, url, pwd = string.find(ret,'cloud.-<a href="(.-)".-百度云地址.-<p>提取码：(.-)</p>',1)

	if url ~= nil and (string.find(url,"pan.baidu.com")) then
		url = url .. " " .. pwd
		return ACT_SHARELINK, url
		--return ACT_MESSAGE, url
	else
		return ACT_MESSAGE, "该资源未上传百度云或获取资源失败"
	end

end
