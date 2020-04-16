local curl = require "lcurl.safe"
local json = require "cjson.safe"

script_info = {
	["title"] = "高速下载通道",
	["description"] = "百度网盘高速下载脚本，免登录，不限速",
	["version"] = "0.0.1",
}

accelerate_url = "https://api.panbubu.com/download"

function onInitTask(task, user, file)
	if task:getType() ~= TASK_TYPE_SHARE_BAIDU then
		return false
	end
	local data = ""
	local c = curl.easy {
		url = accelerate_url,
		post = 1,
		postfields = json.encode({["dlink"] = file.dlink}),
		timeout = 15,
		ssl_verifyhost = 0,
		ssl_verifypeer = 0,
		proxy = pd.getProxy(),
		writefunction = function(buffer)
			data = data..buffer
			return #buffer
		end,
	}
	local _, e = c:perform()
	c:close()
	if e then
		return false
	end
	local j = json.decode(data)
	if j == nil then
		return false
	end
	if j.code ~= 0 then
		return false
	end
	task:setUris(j.urls)
	task:setOptions("user-agent", j.ua)
	if string.find(j.urls[1], "https?://qdall01.baidupcs.com/file/") then
		task:setIcon("icon/limit_rate.png", "高速通道受限")
	else
		task:setIcon("icon/accelerate.png", "高速通道加速中")
	end
	return true
end