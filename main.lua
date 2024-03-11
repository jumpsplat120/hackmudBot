c = require "bin/console/console"
bitser = require "bitser"
-----INIT VALUES---------

local code, thread, chan_read, chan_write, contents, funky_table

chan_read  = love.thread.getChannel("read")
chan_write = love.thread.getChannel("write")

funky_table = {
	log = c.log,
	print = c.print,
	save = function(c, data)
		love.filesystem.write("chat_token.txt", data)
	end,
	delete = function(c)
		love.filesystem.remove("chat_token.txt")
	end
}

-----LOCAL FUNCS-----

local function get()
	return chan_read:pop()
end

local function send(data)
	chan_write:push(data)
end

local function stringify(data)
	return bitser.dumps(data)
end

local function destringify(str)
	return bitser.loads(str)
end

-----LOVE CALLBACKS---------

function love.load()
	c:load()
end

function love.update(dt)
	c:update(dt)
	
	local data = get()
	if data then funky_table[data[1]](c, select(2, unpack(data))) end
end

function love.draw()
	c:draw()
end

function love.wheelmoved(x, y)
	c:wheelmoved(x, y)
end

function love.keypressed(key, scancode, isrepeat)
	c:keypressed(key, scancode, isrepeat)
end

function love.textinput(text)
	c:textinput(text)
end

function love.resize(w, h)
	c:resize(w, h)
end

-----CONSOLE CALLBACKS-----

function c:readwrite(text)
	send(text)
	return {" ", " "}
end

-----NETWORKING THREAD-----


thread = love.thread.newThread("network.lua")
thread:start()

contents, err = love.filesystem.read("chat_token.txt")
if contents then send(contents) end