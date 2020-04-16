local curl = require "lcurl.safe"
local json = require "cjson.safe"


script_info = {
	["title"] = "蓝奏云搜索",
	["version"] = "0.0.6",
	["description"] = "搜索蓝奏云资源，点击下载",
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

function onSearch(key, page)
	if page == 1 then
		interfaceID = pd.choice({"接口1","接口2"}, 1, "请选择")
		if interfaceID == 1 then
			engine = "site%3Apan.lanzou.com+"
		else
			engine = "site%3Awww.lanzous.com+"
		end
	end


	local cookie = setCookie()
	--pd.logInfo("the cookie is:"..cookie)
	local data,p_start,p_end
	--pd.logInfo("start send request")
	data = request({url="https://www.dogedoge.com/results?q="..engine..""..pd.urlEncode(key).."&p="..page,cookie=cookie})

	-- Detect the cookie  Invalid
	if string.find(data,"302 Found") then
		pd.logInfo("the cookie is invalid, reset it")
		cookie = setCookie("reset")
		data = request({url="https://www.dogedoge.com/results?q=site%3Apan.lanzou.com+"..pd.urlEncode(key).."&p="..page,cookie=cookie})

	end

	--pd.logInfo(data)

	 --pd.logInfo("get request data:"..data)
	local result = {}
	local start = 1
	local href,title,lanzou_url
	while true do
		-- get href and title
		--pd.logInfo("start:"..start)
		p_start,p_end,href,title = string.find(data,'<a class="result__a" rel="noopener" href="(.-)".->(.-)</a>',start)
		--pd.logInfo("p_end:"..p_end)
		if href then
			--	get avaliable data
			--	pd.logInfo("get title:"..title)
			--	pd.logInfo("get href:"..href)
			--	complete href
			href = "https://www.dogedoge.com" .. href
			--	get lanzou url
			_,__,lanzou_url = string.find(request({url=href,method="HEAD"}),"Location:.- (%S-)%s")
			 pd.logInfo("lanzou url:"..lanzou_url)
			local single_data = request({url=lanzou_url})
			--pd.logInfo("get lanzou url data:"..(data or ""))
			if single_data then
				local url_type
				if string.find(single_data,"filemoreajax") then
					url_type = "list"
				else
					url_type = "file"
				end
				--pd.logInfo("this url is "..url_type.." url")
				if not string.find(single_data,"输入密码") then
				-- the url do not need password
				local tooltip = string.gsub(title, "<em>(.-)</em>", "%1")
				title = string.gsub(title,"<em>(.-)</em>", "{c #ff0000}%1{/c}")
				table.insert(result,{["url"]=lanzou_url, ["title"]=title, ["description"]=lanzou_url, ["showhtml"] = "true", ["tooltip"] = tooltip, ["url_type"] = url_type})
				end

			end
			start = p_end + 1
		else
			--pd.logInfo("this key words has not avaliable url:"..key)
			break
		end

	end
	return result

end

function onItemClick(item)
	-- get the lanzou_url about clike item
	local lanzou_url = item.url
	-- get url type
	local url_type = item.url_type
	local title
	-- get real download url
	local download_url
	if url_type == "list" then
		download_url,title = getList(lanzou_url)
		--pd.logInfo("get download_url:"..download_url)
	else
		download_url,title = getSingle(lanzou_url)
		--pd.logInfo("get single download_url:"..download_url)
	end



	-- if download url is nil, return error

	if download_url == nil then
		return ACT_ERROR,"不支持的链接"
	elseif pd.addUri then
		pd.addUri(download_url, {["out"] = title})
		return ACT_MESSAGE, "已添加到下载列表"
	else
		--pd.logInfo("start to download:"..download_url)
		return ACT_DOWNLOAD, download_url
	end

end

function getSingle(url)
	local download_url,header,p_strat,p_end,fileName,fileId

	local data = request({url=url})
	if string.find(data,"输入密码") then
		--pd.logInfo("this lanzou url need password"..url)
		return nil
	end

	if not data then
		pd.logInfo("this url can not get data"..url)
		return nil
	end
	-- get file name
	p_strat,p_end,fileName = string.find(data,'<title>(.-) %- 蓝奏云</title>')

	-- structure the request header
	header = {"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.86 Safari/537.36","referer: ".. url}

	-- get file id
	p_strat,p_end,fileId = string.find(data,'[^-]<iframe class="ifr2".-src="(.-)"')
	if not fileId then
		p_strat,p_end,fileId = string.find(data,'[^-]<iframe class=.-src="(.-)"')
	end

	if fileId then
		url = "https://www.lanzous.com" .. fileId
		data = request({url=url,header=header})
		-- get sign
		local sign
		p_strat,p_end,sign = string.find(data,"'sign':'(.-)'")
		if sign then
			--pd.logInfo(sign)
			local para = "action=downprocess&sign="..sign
			-- structure the request header
	header = {"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.86 Safari/537.36","referer: ".. url}
			url = "https://www.lanzous.com/ajaxm.php"
			data = request({url=url,header=header,para=para})
			if data then
				-- pd.logInfo(data)
				-- convert the data to json
				data = json.decode(data)

				zt = data["zt"]
				dom = data["dom"]
				url = data["url"]
				inf = data["inf"]

				if zt ~= "0.0" then
					url = string.gsub(dom,"\\","") .. "/file/" .. url
					url = string.gsub(url,"\\","")
					header = {
			"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.86 Safari/537.36","Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,,application/signed-exchange;v=b3" ,"Accept-Encoding: gzip, deflate, br" ,"Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,et;q=0.7,de;q=0.6"
		}
					data = request({url=url,header=header,method="HEAD"})
					--pd.logInfo("the last data:"..data)
					p_strat,p_end,download_url = string.find(data,'Location: (.-)\n')
					--pd.logInfo("get real download url:"..download_url)
					return download_url,fileName
				end

			else
				pd.logInfo("can not get data,the url is:"..url.."\nthe para is:"..para)
			end
		else
			pd.logInfo("can not get sign,the url is:"..url)
		end

	else
		pd.logInfo("can not get fileId,the url is:"..url)
	end

end

function getList(url)
	local download_url
	local data = request({url=url})
	local header,p_strat,p_end,t_name,k_name,t,k,lx,fid,uid,rep,up

	header = {
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.86 Safari/537.36","referer: ".. url
	}
	url = "https://www.lanzous.com/filemoreajax.php"
	p_strat,p_end,t_name,k_name = string.find(data,"'t':(.-),.-'k':(.-),")

	p_strat,p_end,t,k,lx,fid,uid,rep,up = string.find(data,"var "..t_name.." = '(.-)';.-var "..k_name.." = '(.-)';.-data :.-'lx':(.-),.-'fid':(.-),.-'uid':'(.-)',.-'rep':'(.-)',.-'up':(.-),",1)
		para = "lx="..lx.."&fid="..fid.."&uid="..uid.."&pg=1".."&rep="..rep.."&t="..t.."&k="..k.."&up="..up

	data = request({url=url,header=header,para=para,method="POST"})
	data = json.decode(data)
	if data["info"] == "sucess" then
		local source_list = {}
		local source_show = {}
		for i, v in ipairs(data["text"]) do
			--pd.logInfo(i)
			local title = v["name_all"]
			local size = v["size"]
			local time = v["time"]
			url = "https://www.lanzous.com/" .. v["id"]
			table.insert(source_list,{["url"] = url, ["title"] = title,["size"] = size,["time"] = time})
			--pd.logInfo("get title:"..title)
			table.insert(source_show,title)
		end
		--pd.logInfo("should show the choice")
		local sel = pd.choice(source_show, 1, "请选择")
		--pd.logInfo("the choice is "..sel)
		--pd.logInfo("the choice type is "..type(sel))
		if not sel then
			return nil
		end

		url = source_list[sel]["url"]
		local title = source_list[sel]["title"]
		--pd.logInfo("should download this lanzou url:"..url)
		download_url = getSingle(url)
		return download_url,title
	else
		--pd.logInfo("this request is failed:"..url)
	end
	return download_url

end

function setCookie(flag)
	local cookie

	if not flag then
		cookie = pd.getConfig("DogeCookie", "cookie")
	end

	--pd.logInfo(type(cookie))
	--pd.logInfo("cookie length:"..rawlen(cookie))
	if cookie ~= nil and rawlen(cookie) > 0  then
		pd.logInfo("get doge cookie:"..cookie)

	else
		local url = "https://www.dogedoge.com/results?q=a"
		local data = request({url=url,method="HEAD"})
		--pd.logInfo("get cookie:\n"..data)
		_,__,cookie = string.find(data,"Set%-Cookie: (.-)%s")
		--pd.logInfo("cookie is:"..cookie)
		-- cookie="spot=8b25a8619461a35c05382c2918cd0d96;"
		cookie = cookie..";"
		pd.setConfig("DogeCookie", "cookie", cookie)
		pd.logInfo("set doge cookie:"..cookie)

	end

	return cookie

end





