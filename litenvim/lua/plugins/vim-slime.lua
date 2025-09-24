-- TODO: add function to fold only the current cell 
return {
  -- slime (REPL integration)
  {
    "jpalardy/vim-slime",
    keys = {
      { "<leader>r",  "",                             desc = "+vim-slime" },
      { "<leader>rc", "<CMD>SlimeConfig<CR>",         desc = "Slime Config" },
      -- { "<leader>rr", "<Plug>SlimeSendCell<BAR>/^# %%<CR>", desc = "Slime Send Cell" },
      { "<leader>rr", "<Plug>SlimeSendCell<CR>",      desc = "Slime Send Cell" },
      { "<leader>rr", ":<C-u>'<,'>SlimeSend<CR>", mode = "v",                   desc = "Slime Send Selection" },
      { "<leader>rn", "o# %%<ESC>o<ESC>D",            desc = "Sime Insert New Cell" },
      { "]r",         "/# %%<CR>",                    desc = "Sime Next Cell" },
      { "[r",         "k/# %%<CR>N",                  desc = "Sime Previous Cell" },
      { "<leader>rf", function() _G.SlimeFolds.create_slime_cell_folds() end, desc = "Create folds for slime cells (open)" },
      { "<leader>rF", function() _G.SlimeFolds.create_and_close_slime_cell_folds() end, desc = "Create folds for slime cells (closed)" },

    },
    config = function()
      vim.g.slime_no_mappings = 1
      vim.g.slime_target = "wezterm"
      vim.g.slime_cell_delimiter = "# %%"
      vim.g.slime_bracketed_paste = 1
      vim.g.slime_python_ipython = 0

      -- Function to create folds for vim-slime cells (between # %% markers)
      local function create_slime_cell_folds()
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        local cell_starts = {}

        -- Find all cell delimiter lines
        for i, line in ipairs(lines) do
          if line:match("^%s*#%s*%%%%") then
            table.insert(cell_starts, i)
          end
        end

        -- Helper function to find first non-comment line after a given line
        local function find_first_non_comment(start_idx, end_idx)
          local in_multiline_comment = false
          local multiline_delimiter = nil

          for i = start_idx, end_idx do
            local line = lines[i]:gsub("^%s*", "") -- Remove leading whitespace
            local skip_line = false

            -- Skip empty lines
            if line == "" then
              skip_line = true
            elseif not in_multiline_comment then
              -- Handle multiline comment start
              if line:match('^"""') or line:match("^'''") then
                multiline_delimiter = line:match('^(""")') or line:match("^(''')")
                -- Check if it's a single-line multiline comment
                if line:match(multiline_delimiter .. ".-" .. multiline_delimiter) then
                  skip_line = true -- Single-line multiline comment, skip
                else
                  in_multiline_comment = true
                  skip_line = true
                end
              end
            end

            -- Handle multiline comment end
            if in_multiline_comment and not skip_line then
              if line:find(multiline_delimiter) then
                in_multiline_comment = false
                multiline_delimiter = nil
              end
              skip_line = true
            end

            -- Skip single-line comments (but not cell delimiters)
            if not skip_line and line:match("^#") and not line:match("^#%s*%%%%") then
              skip_line = true
            end

            -- Found first non-comment line
            if not skip_line then
              return i
            end
          end

          return end_idx + 1 -- No non-comment line found
        end

        -- Create folds between cell delimiters
        for i = 1, #cell_starts - 1 do
          local after_delimiter = cell_starts[i] + 1
          local end_line = cell_starts[i + 1] - 1
          local start_line = find_first_non_comment(after_delimiter, end_line)

          -- Only create fold if there's content between delimiters
          if start_line <= end_line then
            vim.cmd(start_line .. "," .. end_line .. "fold")
            vim.cmd(start_line .. "," .. end_line .. "foldopen")
          end
        end

        -- Handle the last cell (from last delimiter to end of file)
        if #cell_starts > 0 then
          local after_delimiter = cell_starts[#cell_starts] + 1
          local end_line = #lines
          local start_line = find_first_non_comment(after_delimiter, end_line)

          if start_line <= end_line then
            vim.cmd(start_line .. "," .. end_line .. "fold")
            vim.cmd(start_line .. "," .. end_line .. "foldopen")
          end
        end
      end

      -- Function to create folds for vim-slime cells and close them
      local function create_and_close_slime_cell_folds()
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        local cell_starts = {}

        -- Find all cell delimiter lines
        for i, line in ipairs(lines) do
          if line:match("^%s*#%s*%%%%") then
            table.insert(cell_starts, i)
          end
        end

        -- Helper function to find first non-comment line after a given line
        local function find_first_non_comment(start_idx, end_idx)
          local in_multiline_comment = false
          local multiline_delimiter = nil

          for i = start_idx, end_idx do
            local line = lines[i]:gsub("^%s*", "") -- Remove leading whitespace
            local skip_line = false

            -- Skip empty lines
            if line == "" then
              skip_line = true
            elseif not in_multiline_comment then
              -- Handle multiline comment start
              if line:match('^"""') or line:match("^'''") then
                multiline_delimiter = line:match('^(""")') or line:match("^(''')")
                -- Check if it's a single-line multiline comment
                if line:match(multiline_delimiter .. ".-" .. multiline_delimiter) then
                  skip_line = true -- Single-line multiline comment, skip
                else
                  in_multiline_comment = true
                  skip_line = true
                end
              end
            end

            -- Handle multiline comment end
            if in_multiline_comment and not skip_line then
              if line:find(multiline_delimiter) then
                in_multiline_comment = false
                multiline_delimiter = nil
              end
              skip_line = true
            end

            -- Skip single-line comments (but not cell delimiters)
            if not skip_line and line:match("^#") and not line:match("^#%s*%%%%") then
              skip_line = true
            end

            -- Found first non-comment line
            if not skip_line then
              return i
            end
          end

          return end_idx + 1 -- No non-comment line found
        end

        -- Create folds between cell delimiters
        for i = 1, #cell_starts - 1 do
          local after_delimiter = cell_starts[i] + 1
          local end_line = cell_starts[i + 1] - 1
          local start_line = find_first_non_comment(after_delimiter, end_line)

          -- Only create fold if there's content between delimiters
          if start_line <= end_line then
            vim.cmd(start_line .. "," .. end_line .. "fold")
          end
        end

        -- Handle the last cell (from last delimiter to end of file)
        if #cell_starts > 0 then
          local after_delimiter = cell_starts[#cell_starts] + 1
          local end_line = #lines
          local start_line = find_first_non_comment(after_delimiter, end_line)

          if start_line <= end_line then
            vim.cmd(start_line .. "," .. end_line .. "fold")
          end
        end
      end

      -- Export functions for use in keymaps
      _G.SlimeFolds = {
        create_slime_cell_folds = create_slime_cell_folds,
        create_and_close_slime_cell_folds = create_and_close_slime_cell_folds
      }
    end,
  },
}
