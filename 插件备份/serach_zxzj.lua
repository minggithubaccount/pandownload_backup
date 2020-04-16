local curl = require "lcurl.safe"

script_info = {
	["title"] = "在线之家",
	["description"] = "https://www.zxzjs.com/",
	["version"] = "0.0.1",
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

	local header = {
			"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.86 Safari/537.36",
		}
		
	local data = request("https://www.zxzjs.com/vodsearch/" .. pd.urlEncode(key) .. "----------" .. page .. "---.html" , header)
	local result = {}
	local start = 1
	
	while true do
		
		local a, b, href, title, img = string.find(data,'<a class="stui%-vodlist__thumb lazyload" href="(.-)" title="(.-)" data%-original="(.-)">',start)
		
		if href == nil then
			break
		end
		
		href = 'https://www.zxzjs.com' .. href


		local ret = request(href , header)
		local start1,end1 = string.find(ret,'<div class="play%-item cont active">.-</ul>',1)
		local count = 1
		while true do

			local start2,end2,href = string.find(ret, '<li.-href="(.-)">',start1)
			-- request(href , header)
			if start2 > end1 then
				break
			else
				href = 'https://www.zxzjs.com' .. href
				local now_title = title .. '_' .. tostring(count)
				table.insert(result, {["href"] = href , ["title"] = now_title,  ["image"] =  img, ["icon_size"] = "47,67" , ["description"] = href})
				start1 = end2 + 1
				count = count + 1
			end

		end
		-- local count = 1
		-- while true do
			
			
		-- 	local ret = request(href , header)
		-- 	local c, d, url_tail = string.find(ret, '</i> 上一集</a>.-<a href="/video/(.-)">下一集 <i class="iconfont icon%-more"></i></a>',1)

		-- 	local now_title = title .. '_' .. tostring(count)
		-- 	table.insert(result, {["href"] = href , ["title"] = href,  ["image"] =  img, ["icon_size"] = "47,67" })
		-- 	if url_tail == nil then
		-- 		break
		-- 	else 
		-- 		count = count + 1
		-- 		href = 'https://www.zxzjs.com/video/' .. url_tail
				
		-- 	end
				
		-- end
		
		start = b + 1
		
	end
	return result
	
	
end

function parseUrl( url )
	-- 请求详情页获取第一个url地址
	local header = {
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.86 Safari/537.36",
		"referer: ".. url
	}
	local ret = request(url,header)
	local a, b, fir_url = string.find( ret,'<script type="text/javascript">.-"url":"(.-)"',1 )
	-- https:\/\/g.shumafen.cn\/api\/file\/ef8736d07d05f871\/5c867d1dc81c4f14.mp4
	fir_url = string.gsub( fir_url,'\\','' )

	-- 请求第一个url地址获取第二个url地址
	local header = {
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.86 Safari/537.36",
		"referer: ".. url
	}
	ret = request(fir_url,header)
	local a, b, sec_url = string.find( ret,'var u="../../(.-)"',1 )
	-- file_u/lzlmlklJlNlIlJlllklzkCNmNNlUlklllNNolJlkNolJlmNNlUlklzwFlmNllUlNlkNolzNoNllUlzNlloNNlzlowENDkJlokClolIlllz
	sec_url = 'https://g.shumafen.cn/api/' .. sec_url


	-- 请求第二个url地址获取真实的下载地址
	local header = {
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.86 Safari/537.36",
		"referer: ".. fir_url
	}
	ret = request(sec_url,header)
	local a, b, rea_url = string.find( ret,'<video src="(.-)" ',1 )
	return rea_url

end

function onItemClick(item)
	
	local sel = pd.choice({"下载", "在线播放"}, 1, "请选择")


	
	local href = item.href
	local link = parseUrl(href)
	local filetype = '.mp4'

	if sel == 2 then
		return ACT_PLAY, link 

	elseif sel == nil then
		-- body
		return ACT_MESSAGE, '取消操作' 
	
	else

		if pd.addUri then
			pd.addUri(link, {["out"] = item.title .. " - "  .. filetype})
			return ACT_MESSAGE, "已添加到下载列表" 
		else
			return ACT_DOWNLOAD, link 
		end

	end



end

