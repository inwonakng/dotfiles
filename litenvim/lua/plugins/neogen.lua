return {
	"danymat/neogen",
	cmd = "Neogen",
	keys = {
		{
			"<leader>cn",
			function()
				require("neogen").generate()
			end,
			desc = "Generate Annotations (Neogen)",
		},
		{
			"<C-n>",
			function()
				require("neogen").jump_next()
			end,
		},
		{
			"<C-p>",
			function()
				require("neogen").jump_prev()
			end,
		},
	},
	opts = function(_, opts)
		opts.snippet_engine = "luasnip"
		local i = require("neogen.types.template").item
		opts["languages"] = {
			python = {
				template = {
					annotation_convention = "google_docstrings_markdown",
					google_docstrings_markdown = {
						{ nil, '"""$1"""', { no_results = true, type = { "class", "func" } } },
						{ nil, '"""$1', { no_results = true, type = { "file" } } },
						{ nil, "", { no_results = true, type = { "file" } } },
						{ nil, "$1", { no_results = true, type = { "file" } } },
						{ nil, '"""', { no_results = true, type = { "file" } } },
						{ nil, "", { no_results = true, type = { "file" } } },

						{ nil, "# $1", { no_results = true, type = { "type" } } },

						{ nil, '"""$1' },
						{ i.HasParameter, "", { type = { "func" } } },
						{ i.HasParameter, "Args:", { type = { "func" } } },
						{ i.Parameter, "    `%s` ($1): $1", { type = { "func" } } },
						{ { i.Parameter, i.Type }, "    `%s`: $1", { required = i.Tparam, type = { "func" } } },
						{ i.ArbitraryArgs, "    `%s`: $1", { type = { "func" } } },
						{ i.Kwargs, "    `%s`: $1", { type = { "func" } } },
						{ i.ClassAttribute, "    `%s`: $1", { before_first_item = { "", "Attributes: " } } },
						{ i.HasReturn, "", { type = { "func" } } },
						{ i.HasReturn, "Returns:", { type = { "func" } } },
						{ i.HasReturn, "    $1", { type = { "func" } } },
						{ i.HasYield, "", { type = { "func" } } },
						{ i.HasYield, "Yields:", { type = { "func" } } },
						{ i.HasYield, "    $1", { type = { "func" } } },
						{ i.HasThrow, "", { type = { "func" } } },
						{ i.HasThrow, "Raises:", { type = { "func" } } },
						{ i.Throw, "    `%s`: $1", { type = { "func" } } },
						{ nil, '"""' },
					},
				},
			},
		}
	end,
}
