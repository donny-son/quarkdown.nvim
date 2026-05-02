# quarkdown.nvim


> DISCLAIMER
> Currently this plugin is in very early development and may break

![demo](https://github.com/user-attachments/assets/c18c8ed2-7164-44be-9e5d-813926fdc851)

Neovim integration for [Quarkdown](https://github.com/iamgio/quarkdown), a
Turing-complete Markdown flavor and typesetting system. This is the Neovim
counterpart to the Quarkdown VS Code extension.

## Features

- File-type detection for `.qd` files
- Syntax highlighting that extends the bundled `markdown` syntax with
  Quarkdown function calls (`.name`, `name::chain`, `arg:{value}`)
- Language server integration through `quarkdown language-server`:
  - Completions for functions, parameters, and values
  - Hover documentation
  - Diagnostics
  - Semantic tokens highlighting
- Convenience commands wrapping the CLI: `:QuarkdownCompile`,
  `:QuarkdownPreview`, `:QuarkdownWatch`, `:QuarkdownCreate`,
  `:QuarkdownRestart`

## Requirements

- Neovim 0.10 or newer
- The `quarkdown` CLI on `$PATH`. Install Quarkdown from
  https://github.com/iamgio/quarkdown and verify with `quarkdown --version`.

## Installation

### lazy.nvim

```lua
{
  "donny-son/quarkdown.nvim",
  ft = "quarkdown",
  config = function()
    require("quarkdown").setup({})
  end,
}
```

For local development, point `dir` at your checkout instead of `"donny-son/..."`:

```lua
{ dir = "/path/to/quarkdown.nvim", name = "quarkdown.nvim", ft = "quarkdown" }
```

### packer.nvim

```lua
use({
  "donny-son/quarkdown.nvim",
  ft = "quarkdown",
  config = function()
    require("quarkdown").setup({})
  end,
})
```

### Manual

Symlink (or copy) the plugin into your runtime path:

```bash
ln -s /path/to/quarkdown.nvim \
      ~/.local/share/nvim/site/pack/quarkdown/start/quarkdown.nvim
```

## Preview modes

Two ways to view the rendered output:

- **`browser` (default).** `:QuarkdownPreview` / `:QuarkdownWatch` run
  `quarkdown compile --preview ...` in a small terminal split and Quarkdown
  opens a real browser tab pointed at its local server. Tile the browser
  next to your terminal with whatever window manager you already use
  (Rectangle, Magnet, yabai, BetterTouchTool, Hammerspoon, GNOME tiling,
  i3, ...). This is the recommended setup because the browser preview is
  fully interactive: live reload, JavaScript, links, code highlighting.

- **`inline`** (opt-in). The PDF output is rasterized and displayed in a
  vertical split inside Neovim via [3rd/image.nvim][image-nvim]. Works in
  terminals that support image protocols: Kitty, iTerm2, Ghostty, WezTerm.
  No browser, no JavaScript, but it stays inside Neovim. Requires the
  `pdftoppm` binary (from poppler) and the document's doctype must produce
  a PDF (`paged`, `slides`).

  ```lua
  require("quarkdown").setup({
    preview = { mode = "inline" },
  })
  ```

  ```bash
  brew install poppler                  # macOS
  sudo apt install poppler-utils        # Debian/Ubuntu
  ```

  Plus install [3rd/image.nvim][image-nvim] alongside this plugin.

[image-nvim]: https://github.com/3rd/image.nvim

## Configuration

Calling `setup()` is optional; the plugin loads with sensible defaults and
auto-attaches the language server to every `.qd` buffer.

```lua
require("quarkdown").setup({
  cmd = { "quarkdown", "language-server" },
  auto_attach = true,
  root_markers = { ".git", "main.qd", "quarkdown.json" },
  capabilities = nil,        -- merged with the default LSP client capabilities
  on_attach = function(client, bufnr)
    -- your keymaps, e.g.
    vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = bufnr })
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = bufnr })
  end,
  settings = {},
  semantic_tokens = true,
  compile = {
    args = {},               -- extra args added to every compile invocation
    output = nil,            -- equivalent to `-o <output>`
    pdf = false,             -- equivalent to `--pdf`
    preview = true,          -- :QuarkdownWatch also passes --preview
    terminal_height = 10,    -- rows for the preview/watch terminal split
  },
  preview = {
    mode = "browser",        -- "browser" (default) or "inline"
    inline = {
      width = 60,            -- columns of the inline preview vsplit
      dpi = 144,             -- pdftoppm rasterization DPI
      page = 1,              -- starting page
      refresh_on_save = true,
      cache_dir = nil,       -- defaults to stdpath("cache").."/quarkdown.nvim"
    },
  },
})
```

## Commands

| Command              | Description                                                      |
| -------------------- | ---------------------------------------------------------------- |
| `:QuarkdownCompile`  | Run `quarkdown compile` on the current buffer                    |
| `:QuarkdownPreview`  | Compile with `--preview` in a terminal split                     |
| `:QuarkdownWatch`    | Compile with `--watch` (and `--preview` by default)              |
| `:QuarkdownCreate`   | Run `quarkdown create` to scaffold a new project                 |
| `:QuarkdownStop`     | Stop the running background task and close its terminal         |
| `:QuarkdownRestart`  | Stop and restart the language server clients                     |

Inline-preview controls (only meaningful when `preview.mode = "inline"`):

| Command                     | Description                                  |
| --------------------------- | -------------------------------------------- |
| `:QuarkdownPreviewClose`    | Close the inline preview split               |
| `:QuarkdownPreviewRefresh`  | Recompile and re-render the current page     |
| `:QuarkdownPreviewNext`     | Show the next page                           |
| `:QuarkdownPreviewPrev`     | Show the previous page                       |
| `:QuarkdownPreviewPage {n}` | Jump to page `{n}`                           |

Inside the preview buffer, `q` closes it, `]p` / `[p` switch pages, and `r`
refreshes.

Only one Quarkdown background task runs at a time. Switching from one to
another (for example `:QuarkdownWatch` while `:QuarkdownPreview` is active)
stops the previous task and reuses the same split. Focus stays in the
editor window when a task starts. Inside the terminal buffer, press `q`
(normal mode) or `<C-q>` (terminal mode) to hide the split without killing
the task; rerun the same command to bring it back.

Any additional arguments are forwarded verbatim to the CLI, e.g.
`:QuarkdownCompile --pdf --strict`.

## Health check

```vim
:checkhealth quarkdown
```

Reports whether the CLI is reachable and whether the running Neovim version
is supported.

## License

Same license as the surrounding Quarkdown repository.
