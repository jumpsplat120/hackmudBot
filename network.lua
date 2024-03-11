local bitser = require "bitser"
local json   = require "json"

local chan_read, chan_write, err, _, send, get, response, token, chat_pass, stringify, destringify
local basic, info, ok, warn, err

function send(data)
	chan_read:push(data)
end

function get()
	return chan_write:pop()
end

function stringify(data)
	return bitser.dumps(data)
end

function destringify(str)
	return bitser.loads(str)
end

function basic(message)
	send({"log", message})
end

function info(message)
	send({"log", message, 1})
end

function ok(message)
	send({"log", message, 2})
end

function warn(message)
	send({"log", message, 3})
end

function err(message)
	send({"log", message, 4})
end

function cprint(message, r, g, b)
	send({"print", message, {r, g, b, 1}})
end

function curl_json(data)
	assert(type(data) == "table", "Unable to parse non-tabular data: type " .. type(data))
	
	local stringy = "{"
	
	for key, val in pairs(data) do
		stringy = stringy .. '\\"' .. key .. '\\":'
		
		if type(val) == "string" then
			stringy = stringy .. '\\"' .. val .. '\\"'
		elseif type(val) == "table" then
			stringy = stringy .. '['
			for i, username in ipairs(val) do stringy = stringy .. '\\"' .. username .. '\\",' end
			stringy = stringy:sub(1, -2) .. "]"
		else
			error("Value was not string or table; " .. tostring(val))
		end
		stringy = stringy .. ","
	end
	stringy = stringy:sub(1, -2) .. "}"

	return stringy
end

function post_req(data, req_type, timeout)
	local pop, str, curr_time
	
	timeout = timeout or 5
	curr_time = os.time()

	pop = io.popen('curl -H "Content-Type: application/json" --data-ascii "' .. curl_json(data) .. '" https://www.hackmud.com/mobile/' .. req_type .. '.json -s')
	
	while not str do 
		str = pop:read("*a")
		if os.time() > curr_time + timeout then break end
	end
	
	pop:close()
	
	if str == "" then err("No data was recieved!") else return json.decode(str) end
end

function every(time, callback)
	local start = os.time()
	local timer = 0
	while true do
		dt = os.time() - start
		timer = timer + dt
		start = start + dt
		
		if timer > time then
			callback()
			timer = 0
		end
	end
end

function request_chat()
	local time = os.time()
	local res = post_req({chat_token = token,
						usernames = { username },
						after     = tostring(time - 2)}, "chats", 1.9)

	local loopy_boi = res.chats and res.chats[username] or {}

	for i, obj in ipairs(loopy_boi) do
		if obj.is_join then
			warn("User " .. obj.from_user .. "has joined.")
		elseif obj.is_leave then
			warn("User " .. obj.from_user .. "has left.")
		elseif obj.channel then
			basic(obj.msg)
		elseif obj.msg then
			info(obj.msg)
		else
			err("Some sort of response was received, but did not validate.")
		end
	end
end

chan_read  = love.thread.getChannel("read")
chan_write = love.thread.getChannel("write")

cprint(" _  _   _   ___ _  ____  __ _   _ ___  ", 0, 1, 1)
cprint("| || | /_\\ / __| |/ /  \\/  | | | |   \\ ", 0, 1, 1)
cprint("| __ |/ _ \\ (__| ' <| |\\/| | |_| | |) |", 0, 1, 1)
cprint("|_||_/_/ \\_\\___|_|\\_\\_|  |_|\\___/|___/ ", 0, 1, 1)
cprint(" ", 0, 0, 0)
basic("Starting up process...")
basic("Looking for token...")

token = get()

::start_token_process::

if not token then 
	warn("No token found. Please enter chat_pass:")
	
	while chat_pass == nil do chat_pass = get() end
	
	ok("Received chat_pass: " .. chat_pass .. ".")
	basic("Attempting to retrieve token...")
	
	response = post_req({pass = chat_pass}, "get_token")
	
	if response.ok then
		token = response.chat_token
		send({"save", token})
	else
		err("Unable to retrieve token: " .. (response.msg or response.error))
		goto start_token_process
	end
end

ok("Token retrieved: **********")

::start_username_process::

info("Please enter username of bot: ")

username = nil

while username == nil do username = get() end

ok("Recieved username: " .. username)

basic("Verifying user '" .. username .. "'...")

response = post_req({chat_token = token}, "account_data") or { ok = false, msg = "Fallback error; possible invalid token."}

local expected_channels = {"0000", "town", "7001"}
local filter_channels = {}

if response.ok then
	if response.users[username] then
		local all_valid_channels = {}
		for channel, channel_users in pairs(response.users[username]) do
			basic("User was found in channel '" .. channel .. "'.")
			for index, expected in ipairs(expected_channels) do
				if expected == channel 
					then info("'" .. channel .. "' is an expected channel.")
					filter_channels[#filter_channels + 1] = channel
				end
			end
			all_valid_channels[#all_valid_channels + 1] = channel
		end
		
		if #filter_channels > 0 then
			local channel_list = ""
			if #filter_channels == 1 then channel_list = "'" .. filter_channels[1] .. "'."
			else
				for i, item in ipairs(filter_channels) do
					if i == #filter_channels then
						channel_list = channel_list .. "and '" .. item .. "'."
					elseif i == #filter_channels - 1 then
						channel_list = channel_list .. "'" .. item .. "' "
					else
						channel_list = channel_list .. "'" .. item .. "', "
					end
				end
			end
			basic("Input will be filtered down to channel(s) " .. channel_list)
		else
			warn("No channels in the expected_channels table showed up. Test channel mode active.")
			
			::start_custom_channel_process::
			
			info("Please enter a valid test channel: ")
			
			local new_channel

			while new_channel == nil do new_channel = get() end
			
			local is_valid = false
			for index, valid_channels in ipairs(all_valid_channels) do
				if valid_channels == new_channel then is_valid = true end
			end
			
			if is_valid then
				ok("Channel '" .. new_channel .. "' is recieved and valid.")
				filter_channels = { new_channel }
			else
				warn("Channel '" .. new_channel .. "' was recieved but is not valid.")
				goto start_custom_channel_process
			end
		end
	else
		warn("Unable to find user '" .. username .. "'.")
		goto start_username_process
	end
else
	err_msg = response.msg or response.error
	err("Issue with chat request: " .. err_msg)
	
	if err_msg:find("no valid usernames") then
		goto start_username_process
	else
		token = nil
		send({"delete"})
		goto start_token_process
	end
end

ok("Setup is finished! Getting chat_logs...")

every(2, request_chat)