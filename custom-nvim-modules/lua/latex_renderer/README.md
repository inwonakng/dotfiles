# LaTeX Renderer

A shared Neovim module used by `litenvim` and `pi-nvim` to render Markdown math.

## Rendering

The setup uses two complementary rendering paths:

- **Display math:** this module compiles equations to transparent PNGs and places them with the Kitty graphics protocol.
- **Inline math:** `render-markdown.nvim` sends equations to `utftex` and displays the resulting Unicode.

Delegating inline conversion to `utftex` supports constructs such as `\mathcal`, `\mathbb`, fractions, roots, and scripts without maintaining a partial LaTeX parser here.

## Dependencies

### Neovim

- A recent Neovim with `vim.system`, `vim.fs`, Tree-sitter, extmarks, and `vim.api.nvim_ui_send` (tested with Neovim 0.12).
- `nvim-treesitter` with the `markdown`, `markdown_inline`, and `latex` parsers.
- `render-markdown.nvim` for inline Unicode rendering.

### Executables

- `pdflatex`, provided by TeX Live or MacTeX.
- ImageMagick's `magick` executable.
- `utftex` for inline LaTeX-to-Unicode conversion.

The TeX installation must provide `standalone`, `xcolor`, `amsmath`, `amssymb`, `amsfonts`, `amscd`, and `mathtools`.

On macOS, ImageMagick and utftex can be installed with:

```sh
brew install imagemagick utftex
```

Install MacTeX or another TeX Live distribution separately to provide `pdflatex` and the required packages.

### Terminal

- A terminal implementing the Kitty graphics protocol, such as Kitty or Ghostty.
- When running inside tmux, `allow-passthrough` must be enabled.

The nested-client hooks in `tmux/tmux.conf.shared` set `@graphics-nest-count`. The renderer reads that value so graphics sent from the nested `scratch` popup receive the correct number of tmux passthrough wrappers.

## Configuration

Display rendering is configured with:

```lua
require("latex_renderer").setup({
    scale = 0.8,
})
```

Available options and their defaults are:

```lua
{
    debounce_ms = 30,
    max_width = 80,
    max_height = 30,
    prefetch_lines = 30,
    scale = 0.8,
}
```

`scale` controls the displayed image dimensions. `max_width` and `max_height` cap those dimensions in terminal cells.

Inline rendering is configured through `render-markdown.nvim`:

```lua
latex = {
    enabled = true,
    converter = "utftex",
    inline = true,
    block = false,
}
```

`block = false` prevents render-markdown from conflicting with this module's display-image renderer.

## Behavior

- Display equations are found through Markdown's injected LaTeX Tree-sitter trees.
- Only equations in or near a visible viewport are compiled.
- Raw source is shown while the cursor is inside a display equation.
- PNGs are cached under `stdpath("cache")/latex-renderer` using the source and foreground color.
- At most two LaTeX compilation jobs run concurrently.
- `:LatexRendererRefresh` retries failed equations and retransmits cached images.

## Files

- `init.lua`: scanning, scheduling, layout, and buffer lifecycle.
- `compiler.lua`: asynchronous LaTeX compilation and PNG caching.
- `kitty.lua`: Kitty protocol encoding, placement, and tmux wrapping.

Terminal image placement and tmux passthrough require manual visual verification.
