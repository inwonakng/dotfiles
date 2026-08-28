local M = {}

local cache = {}
local pending = {}

local function executable()
	local path = vim.fn.exepath("utftex")
	return path ~= "" and path or nil
end

local function has_subscribers(job)
	for _, subscriber in ipairs(job.subscribers) do
		if subscriber.active then
			return true
		end
	end
	return false
end

local function subscribe(job, callback)
	local subscriber = { active = true, callback = callback }
	job.subscribers[#job.subscribers + 1] = subscriber
	return function()
		if not subscriber.active then
			return
		end
		subscriber.active = false
		if not has_subscribers(job) then
			job.accepting = false
			if job.process then
				pcall(job.process.kill, job.process, "sigterm")
			end
		end
	end
end

local function finish(job, output, err)
	if pending[job.source] == job then
		pending[job.source] = nil
	end
	job.process = nil
	if output then
		cache[job.source] = output
	end
	local callbacks = {}
	for _, subscriber in ipairs(job.subscribers) do
		if subscriber.active then
			callbacks[#callbacks + 1] = subscriber.callback
		end
	end
	vim.schedule(function()
		for _, callback in ipairs(callbacks) do
			callback(output, err)
		end
	end)
end

local function error_message(result)
	local message = vim.trim(result.stderr or "")
	if message == "" then
		message = vim.trim(result.stdout or "")
	end
	message = vim.split(message, "\n", { plain = true })[1] or ""
	message = message:gsub("^ERROR:%s*", "")
	if #message > 200 then
		message = message:sub(1, 197) .. "..."
	end
	return message == "" and "utftex failed" or "utftex: " .. message
end

function M.available()
	return executable() ~= nil
end

function M.convert(source, callback)
	local cached = cache[source]
	if cached then
		vim.schedule(function()
			callback(cached)
		end)
		return function() end
	end

	local command = executable()
	if not command then
		vim.schedule(function()
			callback(nil, "latex-renderer requires utftex for inline math")
		end)
		return function() end
	end

	local existing = pending[source]
	if existing and existing.accepting then
		return subscribe(existing, callback)
	end

	local job = {
		accepting = true,
		source = source,
		subscribers = {},
	}
	pending[source] = job
	local cancel = subscribe(job, callback)
	job.process = vim.system({ command }, { stdin = source, text = true, timeout = 15000 }, function(result)
		local output = (result.stdout or ""):gsub("\r\n", "\n"):gsub("\n+$", "")
		if result.code == 0 and output ~= "" then
			finish(job, output)
		else
			finish(job, nil, error_message(result))
		end
	end)
	return cancel
end

return M
