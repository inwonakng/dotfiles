local M = {}

local function valid_buf(buf)
	return type(buf) == "number" and vim.api.nvim_buf_is_valid(buf)
end

function M.prepare_buffer(buf, opts)
	if not valid_buf(buf) then
		return
	end
	opts = opts or {}

	if opts.latex then
		-- render-latex.nvim currently refuses to attach to unlisted buffers.
		vim.api.nvim_set_option_value("buflisted", true, { buf = buf })
	end

	pcall(vim.treesitter.start, buf, opts.treesitter or "markdown")
end

function M.render(buf, win, opts)
	if not valid_buf(buf) then
		return
	end
	opts = opts or {}

	if type(win) == "number" and vim.api.nvim_win_is_valid(win) then
		local ok_render_markdown, render_markdown = pcall(require, "render-markdown")
		if ok_render_markdown and type(render_markdown.render) == "function" then
			render_markdown.render({
				buf = buf,
				win = win,
				event = opts.event or "PiNvim",
			})
		end
	end

	if not opts.latex then
		return
	end

	local ok_config, config = pcall(require, "render_latex.config")
	local ok_sources, sources = pcall(require, "render_latex.sources")
	local ok_renderer, renderer = pcall(require, "render_latex.renderer")
	if not ok_config or not ok_sources or not ok_renderer or not config.enabled then
		return
	end
	if not sources.supports(buf) then
		return
	end
	renderer.attach(buf)
	renderer.queue(buf)
end

return M
