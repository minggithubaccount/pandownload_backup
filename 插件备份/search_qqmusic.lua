local curl = require "lcurl.safe"
local json = require "cjson.safe"

script_info = {
	["title"] = "QQ音乐",
	["description"] = "QQ音乐搜索功能，支持无损、付费和无版权歌曲下载\n输入 【:config】 进入设置页面\n设置里可切换下载或在线播放\n如果在线播放调用的播放器不正确，请修改m3u格式文件的默认打开方式",
	["version"] = "0.0.3",
	["color"] = "#31c27c",
}

function onSearch(key, page)
	if key == ":config" or key == "【:config】" then
		if page == 1 then
			local config = {}
			local click = pd.getConfig("QQMusic", "click")
			local quality = pd.getConfig("QQMusic", "quality")
			table.insert(config, {["title"] = "点击列表项", ["enabled"] = "false"})
			table.insert(config, createConfigItem("下载", "click", "download", #click == 0 or click == "download"))
			table.insert(config, createConfigItem("播放", "click", "play", click == "play"))
			table.insert(config, {["title"] = "优先下载品质", ["enabled"] = "false"})
			table.insert(config, createConfigItem("SQ无损品质", "quality", "super", #quality == 0 or quality == "super"))
			table.insert(config, createConfigItem("HQ高品质", "quality", "high", quality == "high"))
			table.insert(config, createConfigItem("标准品质", "quality", "standard", quality == "standard"))
			return config
		else
			return {}
		end
	end
	local data = get("https://c.y.qq.com/soso/fcgi-bin/client_search_cp?ct=24&qqmusic_ver=1298&new_json=1&remoteplace=txt.yqq.song&searchid=0&t=0&aggr=1&cr=1&catZhida=1&lossless=0&flag_qc=0&p=" .. page .. "&n=20&g_tk=5381&loginUin=0&hostUin=0&format=jsonp&inCharset=utf8&outCharset=utf-8&notice=0&platform=yqq&needNewCode=0&w=" .. urlEncode(key))
	data = string.gsub(data, "^.-%((.-)%)$", "%1", 1)
	return parse(data)
end

function onItemClick(item)
	if item.isConfig then
		if item.isSel == "1" then
			return ACT_NULL
		else
			pd.setConfig("QQMusic", item.key, item.val)
			return ACT_MESSAGE, "设置成功! (请手动刷新页面)"
		end
	end
	if item.time == "00:00" then
		return ACT_ERROR, "该歌曲暂无音频资源"
	end
	math.randomseed(os.time())
	local guid = math.random(9000000000, 9999999999)
	local j = json.decode(get("https://u.y.qq.com/cgi-bin/musicu.fcg?data=" .. urlEncode(string.format('{"req_0":{"module":"vkey.GetVkeyServer","method":"CgiGetVkey","param":{"guid":"%s","songmid":["%s"],"songtype":[0],"uin":"0","loginflag":1,"platform":"20"}}}', guid, item.mid))))
	local _, _, vkey = string.find(j.req_0.data.testfile2g, "vkey=(.-)&")
	local mid = string.sub(j.req_0.data.midurlinfo[1].filename, 5, -5)
	local link = ""
	local quality = pd.getConfig("QQMusic", "quality")
	if #quality == 0 or quality == "super" then
		quality = 0
	elseif quality == "high" then
		quality = 1
	elseif quality == "standard" then
		quality = 2
	end
	local filetype = ""
	if item.file_flac and quality == 0 then
		link = string.format("http://183.131.60.16/amobile.music.tc.qq.com/F000%s.flac?guid=%s&vkey=%s&uin=0&fromtag=58", mid, guid, vkey)
		filetype = ".flac"
	elseif item.file_320 and quality < 2 then
		link = string.format("http://183.131.60.16/amobile.music.tc.qq.com/M800%s.mp3?guid=%s&vkey=%s&uin=0&fromtag=58", mid, guid, vkey)
		filetype = ".mp3"
	elseif item.file_128 then
		link = string.format("http://183.131.60.16/amobile.music.tc.qq.com/M500%s.mp3?guid=%s&vkey=%s&uin=0&fromtag=58", mid, guid, vkey)
		filetype = ".mp3"
	else
		link = string.format("http://183.131.60.16/amobile.music.tc.qq.com/C400%s.m4a?guid=%s&vkey=%s&uin=0&fromtag=58", mid, guid, vkey)
		filetype = ".m4a"
	end
	if pd.getConfig("QQMusic", "click") == "play" then
		return ACT_PLAY, link 
	else
		if pd.addUri then
			pd.addUri(link, {["out"] = item.singer .. " - " .. item.name .. filetype})
			return ACT_MESSAGE, "已添加到下载列表" 
		else
			return ACT_DOWNLOAD, link 
		end
	end
end

function get(url)
	local r = ""
	local c = curl.easy{
		url = url,
		ssl_verifyhost = 0,
		ssl_verifypeer = 0,
		followlocation = 1,
		timeout = 30,
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
	local j = json.decode(data)
	if j == nil or j.data == nil or j.data.song == nil or j.data.song.list == nil then
		return result
	end
	for _, song in ipairs(j.data.song.list) do 
		table.insert(result, parseSong(song))
		for _, item in ipairs(song.grp) do 
			table.insert(result, parseSong(item))
		end
	end
	return result
end

function parseSong(song)
	local item = {}
	local singer_name, singer_mid, album_name = "", "", ""
	for _, singer in ipairs(song.singer) do 
		if #singer_mid == 0 then
			singer_mid = singer.mid
		end
		if #singer_name > 0 then
			singer_name = singer_name .. " / "
		end
		singer_name = singer_name .. singer.title
	end
	description = "歌手：" .. singer_name
	if #song.album.title > 0 and song.album.title ~= "   " then
		description = description .. "  专辑：" .. song.album.title
		item.image = "https://y.gtimg.cn/music/photo_new/T002R300x300M000" .. song.album.mid .. ".jpg"
	end
	if item.image == nil then
		item.image = "https://y.gtimg.cn/music/photo_new/T001R300x300M000" .. singer_mid .. ".jpg"
	end
	if song.file.size_flac > 0 then
		item.file_flac = "1"
	end
	if song.file.size_320 > 0 then
		item.file_320 = "1"
	end
	if song.file.size_128 > 0 then
		item.file_128 = "1"
	end
	if item.file_flac then
		item.title = song.title .. "  {f 9}{c #ff6600}SQ{/c}{/f}"
	elseif item.file_320 then
		item.title = song.title .. "  {f 9}{c #31c27c}HQ{/c}{/f}"
	else
		item.title = song.title
	end
	item.mid = song.mid
	item.name = conv(song.title)
	item.singer = conv((string.gsub(singer_name, " / ", ",")))	
	item.icon_size = "55,55"
	item.description = description
	item.time = string.format("%02d:%02d", math.floor(song.interval / 60), song.interval % 60)
	item.tooltip = song.title
	item.showhtml = "true"
	return item
end

function createConfigItem(title, key, val, isSel)
	local item = {}
	item.title = title
	item.key = key
	item.val = val
	item.icon_size = "14,14"
	item.isConfig = "1"
	if isSel then
		item.image = "option/selected.png"
		item.isSel = "1"
	else
		item.image = "option/normal.png"
		item.isSel = "0"
	end
	return item
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

function conv(s)
	s = string.gsub(s, "%?", "？")
	s = string.gsub(s, "%*", "＊")
	s = string.gsub(s, ":", "：")
	return s
end