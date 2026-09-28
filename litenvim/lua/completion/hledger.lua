local M = {}

local CACHE_TTL_MS = 30000
local account_query

local function get_account_query()
	if account_query then
		return account_query
	end
	local ok, query = pcall(vim.treesitter.query.parse, "ledger", "(posting (account) @account)")
	if ok then
		account_query = query
	end
	return account_query
end

local function empty_response()
	return {
		items = {},
		is_incomplete_forward = false,
		is_incomplete_backward = false,
	}
end

local function root_journal_path()
	local path = vim.env.LEDGER_FILE
	if not path or path == "" then
		path = "~/.hledger.journal"
	end
	path = vim.fn.expand(path)
	return vim.uv.fs_realpath(path) or vim.fs.normalize(path)
end

local function read_file(path)
	local ok, lines = pcall(vim.fn.readfile, path, "b")
	if not ok then
		return nil
	end
	return table.concat(lines, "\n")
end

local function parse_aliases(text)
	local aliases = {}
	if not text then
		return aliases
	end

	for line in text:gmatch("[^\n]+") do
		local name, target = line:match("^%s*alias%s+([^=]-)%s*=%s*(.-)%s*$")
		if name and target and name ~= "" and target ~= "" and name:sub(1, 1) ~= "/" then
			aliases[name] = target
		end
	end
	return aliases
end

local function parse_accounts(text)
	local accounts = {}
	if not text or text == "" then
		return accounts
	end

	local query = get_account_query()
	if not query then
		return accounts
	end
	local ok, parser = pcall(vim.treesitter.get_string_parser, text, "ledger")
	if not ok then
		return accounts
	end
	local trees = parser:parse()
	if not trees or not trees[1] then
		return accounts
	end

	for id, node in query:iter_captures(trees[1]:root(), text, 0, -1) do
		if query.captures[id] == "account" then
			local account = vim.trim(vim.treesitter.get_node_text(node, text))
			if account ~= "" then
				accounts[account] = true
			end
		end
	end
	return accounts
end

local function discovered_files(stdout, root_path)
	local files = {}
	local seen = {}

	local function add(path)
		if not path or path == "" then
			return
		end
		local resolved = vim.uv.fs_realpath(path) or vim.fs.normalize(path)
		if not seen[resolved] then
			seen[resolved] = true
			table.insert(files, resolved)
		end
	end

	add(root_path)
	for _, path in ipairs(vim.split(stdout or "", "\n", { plain = true, trimempty = true })) do
		add(path)
	end
	return files
end

local function alias_expansion(account, aliases)
	local matched_name
	for name in pairs(aliases) do
		if account == name or vim.startswith(account, name .. ":") then
			if not matched_name or #name > #matched_name then
				matched_name = name
			end
		end
	end
	if not matched_name then
		return nil
	end
	return aliases[matched_name] .. account:sub(#matched_name + 1)
end

local function build_candidates(root_path, stdout)
	local aliases = parse_aliases(read_file(root_path))
	local accounts = {}

	for _, path in ipairs(discovered_files(stdout, root_path)) do
		for account in pairs(parse_accounts(read_file(path))) do
			accounts[account] = true
		end
	end

	local candidates = {}
	for name, target in pairs(aliases) do
		table.insert(candidates, {
			label = name,
			detail = "alias → " .. target,
			sort_text = "0" .. name,
		})
		accounts[name] = nil
	end
	for account in pairs(accounts) do
		local expansion = alias_expansion(account, aliases)
		table.insert(candidates, {
			label = account,
			detail = expansion and ("alias → " .. expansion) or nil,
			sort_text = "1" .. account,
		})
	end

	table.sort(candidates, function(a, b)
		return a.sort_text < b.sort_text
	end)
	return candidates
end

local function inside_transaction(bufnr, row)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end
	for index = row - 1, 0, -1 do
		local line = vim.api.nvim_buf_get_lines(bufnr, index, index + 1, false)[1]
		if not line or line:match("^%s*$") then
			return false
		end
		if not line:match("^%s") then
			return line:match("^%d") ~= nil
		end
	end
	return false
end

local function account_range(ctx)
	local cursor_col = ctx.pos.col
	if not inside_transaction(ctx.bufnr, ctx.pos.row) then
		return nil
	end
	local before_cursor = ctx.line:sub(1, cursor_col)
	local indentation = before_cursor:match("^(%s+)")
	if not indentation then
		return nil
	end

	local start_index = #indentation + 1
	local marker = before_cursor:sub(start_index, start_index)
	if marker == ";" then
		return nil
	end
	if marker == "*" or marker == "!" then
		start_index = start_index + 1
		while before_cursor:sub(start_index, start_index):match("%s") do
			start_index = start_index + 1
		end
	end
	marker = before_cursor:sub(start_index, start_index)
	if marker == "[" or marker == "(" then
		start_index = start_index + 1
	end

	local account = before_cursor:sub(start_index)
	if account:match("^[%w_-]+:%s")
		or account:find("%s%s")
		or account:find("\t", 1, true)
		or account:find("]", 1, true)
		or account:find(")", 1, true)
	then
		return nil
	end

	return {
		start = { line = ctx.pos.row, character = start_index - 1 },
		["end"] = { line = ctx.pos.row, character = cursor_col },
	}
end

local source = {}

function source.new()
	local self = setmetatable({}, { __index = source })
	self.cache = nil
	self.cache_root = nil
	self.cache_time = 0
	self.loading = false
	self.waiters = {}

	local group = vim.api.nvim_create_augroup("HledgerCompletionCache", { clear = true })
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		pattern = "*",
		callback = function(args)
			if vim.bo[args.buf].filetype == "ledger" then
				self.cache_time = 0
			end
		end,
	})
	return self
end

function source:enabled()
	return vim.bo.filetype == "ledger"
end

function source:complete(candidates, range, callback)
	local kind = require("blink.cmp.types").CompletionItemKind.Field
	local items = {}
	for _, candidate in ipairs(candidates) do
		table.insert(items, {
			label = candidate.label,
			kind = kind,
			detail = candidate.detail,
			sortText = candidate.sort_text,
			textEdit = {
				newText = candidate.label,
				range = range,
			},
		})
	end
	callback({
		items = items,
		is_incomplete_forward = false,
		is_incomplete_backward = false,
	})
end

function source:finish_reload(root_path, stdout)
	self.cache = build_candidates(root_path, stdout)
	self.cache_root = root_path
	self.cache_time = vim.uv.now()
	self.loading = false

	local remaining = {}
	for _, waiter in ipairs(self.waiters) do
		if not waiter.cancelled then
			if waiter.root == root_path then
				self:complete(self.cache, waiter.range, waiter.callback)
			else
				table.insert(remaining, waiter)
			end
		end
	end
	self.waiters = remaining
	if remaining[1] then
		self:reload(remaining[1].root)
	end
end

function source:reload(root_path)
	self.loading = true
	if vim.fn.executable("hledger") ~= 1 then
		self:finish_reload(root_path, "")
		return
	end

	vim.system({ "hledger", "files" }, { text = true }, function(result)
		vim.schedule(function()
			self:finish_reload(root_path, result.code == 0 and result.stdout or "")
		end)
	end)
end

function source:get_completions(ctx, callback)
	local range = account_range(ctx)
	if not range then
		callback(empty_response())
		return
	end

	local root_path = root_journal_path()
	local cache_valid = self.cache
		and self.cache_root == root_path
		and vim.uv.now() - self.cache_time < CACHE_TTL_MS
	if cache_valid then
		self:complete(self.cache, range, callback)
		return
	end

	local waiter = { callback = callback, range = range, root = root_path, cancelled = false }
	table.insert(self.waiters, waiter)
	if not self.loading then
		self:reload(root_path)
	end
	return function()
		waiter.cancelled = true
	end
end

M.new = source.new

return M
