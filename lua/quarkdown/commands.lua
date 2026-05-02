local config = require("quarkdown.config")

local M = {}

-- Single shared slot: only one Quarkdown background task (preview, watch,
-- create, ...) is ever running at a time. Re-running any of these commands
-- replaces the previous task in the same window.
local task = { job = nil, bufnr = nil, label = nil }

local function quarkdown_executable()
  local cmd = config.options.cmd or { "quarkdown" }
  return cmd[1] or "quarkdown"
end

local function ensure_executable()
  local exe = quarkdown_executable()
  if vim.fn.executable(exe) ~= 1 then
    vim.notify(("quarkdown.nvim: %q not found on PATH"):format(exe), vim.log.levels.ERROR)
    return nil
  end
  return exe
end

local function buffer_path(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    vim.notify("quarkdown.nvim: current buffer has no file path", vim.log.levels.ERROR)
    return nil
  end
  if vim.bo[bufnr].modified then
    vim.cmd("silent! write")
  end
  return name
end

local function job_alive()
  if not task.job then return false end
  if not task.bufnr or not vim.api.nvim_buf_is_valid(task.bufnr) then return false end
  local ok, pid = pcall(vim.fn.jobpid, task.job)
  return ok and type(pid) == "number" and pid > 0
end

local function buffer_window(bufnr)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      return win
    end
  end
  return nil
end

local function terminal_height()
  return (config.options.compile and config.options.compile.terminal_height) or 10
end

local function open_split_for(bufnr, height)
  vim.cmd("botright " .. tostring(height) .. "split")
  local win = vim.api.nvim_get_current_win()
  if bufnr then
    vim.api.nvim_win_set_buf(win, bufnr)
  end
  vim.api.nvim_win_set_height(win, height)
  vim.wo[win].winfixheight = true
  return win
end

local function configure_term_buffer(bufnr, label)
  vim.bo[bufnr].buflisted = false
  pcall(vim.api.nvim_buf_set_name, bufnr, "quarkdown://" .. label)
  vim.keymap.set("n", "q", "<cmd>hide<cr>", { buffer = bufnr, nowait = true, silent = true })
  vim.keymap.set("t", "<C-q>", [[<C-\><C-n><cmd>hide<cr>]], { buffer = bufnr, nowait = true, silent = true })
end

-- Wipe any quarkdown:// buffer that we don't currently own. Old, dead
-- terminals from previous runs (or before single-instance was added) tend to
-- linger and create the illusion of duplicate splits.
local function purge_orphan_terminals()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and b ~= task.bufnr then
      local name = vim.api.nvim_buf_get_name(b)
      if name:match("^quarkdown://") then
        pcall(vim.api.nvim_buf_delete, b, { force = true })
      end
    end
  end
end

local function reset_task()
  task = { job = nil, bufnr = nil, label = nil }
end

local function stop_current_task()
  if task.job then
    pcall(vim.fn.jobstop, task.job)
  end
  if task.bufnr and vim.api.nvim_buf_is_valid(task.bufnr) then
    pcall(vim.api.nvim_buf_delete, task.bufnr, { force = true })
  end
  reset_task()
end

local function focus_existing()
  local win = buffer_window(task.bufnr)
  if win then
    return win
  end
  return open_split_for(task.bufnr, terminal_height())
end

local function start_task(label, cmd, cwd)
  if job_alive() and task.label == label then
    -- Same task already running: just make sure its split is visible, but
    -- don't steal focus from the originating window.
    local origin_win = vim.api.nvim_get_current_win()
    focus_existing()
    if vim.api.nvim_win_is_valid(origin_win) then
      vim.api.nvim_set_current_win(origin_win)
    end
    vim.notify(("quarkdown: %s already running"):format(label), vim.log.levels.INFO)
    return
  end

  -- Different task (or stale state): tear down before starting fresh.
  stop_current_task()
  purge_orphan_terminals()

  local origin_win = vim.api.nvim_get_current_win()
  local height = terminal_height()
  local term_win = open_split_for(nil, height)

  local job_id = vim.fn.termopen(cmd, {
    cwd = cwd,
    on_exit = function(_, code)
      vim.schedule(function()
        if code == 0 then
          vim.notify("quarkdown: " .. label .. " done", vim.log.levels.INFO)
        else
          vim.notify(("quarkdown: %s exited with code %d"):format(label, code), vim.log.levels.WARN)
        end
        if task.label == label then
          reset_task()
        end
      end)
    end,
  })
  if job_id <= 0 then
    vim.notify("quarkdown: failed to start " .. label, vim.log.levels.ERROR)
    pcall(vim.api.nvim_win_close, term_win, true)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  configure_term_buffer(bufnr, label)
  task = { job = job_id, bufnr = bufnr, label = label }

  -- Hand focus back to the editor window the user invoked the command from.
  if vim.api.nvim_win_is_valid(origin_win) then
    vim.api.nvim_set_current_win(origin_win)
  end
end

local function run_oneshot(cmd, label, cwd)
  vim.system(cmd, { cwd = cwd, text = true }, function(out)
    vim.schedule(function()
      if out.code == 0 then
        vim.notify("quarkdown: " .. label .. " done", vim.log.levels.INFO)
      else
        vim.notify(
          ("quarkdown: %s failed (%d)\n%s"):format(label, out.code, out.stderr or ""),
          vim.log.levels.ERROR
        )
      end
    end)
  end)
end

local function build_compile_args(extra)
  local cfg = config.options.compile or {}
  local args = { "compile" }
  if cfg.output then
    table.insert(args, "-o")
    table.insert(args, cfg.output)
  end
  if cfg.pdf then
    table.insert(args, "--pdf")
  end
  for _, a in ipairs(cfg.args or {}) do
    table.insert(args, a)
  end
  for _, a in ipairs(extra or {}) do
    table.insert(args, a)
  end
  return args
end

function M.compile(opts)
  opts = opts or {}
  local exe = ensure_executable()
  if not exe then return end
  local file = buffer_path(0)
  if not file then return end
  local args = build_compile_args(opts.fargs)
  table.insert(args, file)
  run_oneshot({ exe, unpack(args) }, "compile", vim.fs.dirname(file))
end

local function preview_mode()
  return (config.options.preview and config.options.preview.mode) or "browser"
end

function M.preview(opts)
  opts = opts or {}
  local file = buffer_path(0)
  if not file then return end
  if preview_mode() == "inline" then
    require("quarkdown.preview").start(file)
    return
  end
  local exe = ensure_executable()
  if not exe then return end
  local args = build_compile_args(opts.fargs)
  table.insert(args, "--preview")
  table.insert(args, file)
  start_task("preview", { exe, unpack(args) }, vim.fs.dirname(file))
end

function M.watch(opts)
  opts = opts or {}
  local file = buffer_path(0)
  if not file then return end
  if preview_mode() == "inline" then
    -- Inline watch = inline preview with refresh_on_save (the default).
    require("quarkdown.preview").start(file)
    return
  end
  local exe = ensure_executable()
  if not exe then return end
  local args = build_compile_args(opts.fargs)
  table.insert(args, "--watch")
  if config.options.compile.preview ~= false then
    table.insert(args, "--preview")
  end
  table.insert(args, file)
  start_task("watch", { exe, unpack(args) }, vim.fs.dirname(file))
end

function M.create(opts)
  opts = opts or {}
  local exe = ensure_executable()
  if not exe then return end
  local args = { "create" }
  vim.list_extend(args, opts.fargs or {})
  start_task("create", { exe, unpack(args) }, nil)
end

function M.stop()
  local stopped_inline = false
  local ok_preview, preview_mod = pcall(require, "quarkdown.preview")
  if ok_preview and preview_mod.is_active() then
    preview_mod.stop()
    stopped_inline = true
  end
  if not job_alive() then
    purge_orphan_terminals()
    reset_task()
    if not stopped_inline then
      vim.notify("quarkdown: no running task", vim.log.levels.INFO)
    else
      vim.notify("quarkdown: stopped inline preview", vim.log.levels.INFO)
    end
    return
  end
  local label = task.label
  stop_current_task()
  purge_orphan_terminals()
  vim.notify("quarkdown: stopped " .. (label or "task"), vim.log.levels.INFO)
end

function M.restart_lsp()
  require("quarkdown.lsp").restart()
end

function M.register()
  vim.api.nvim_create_user_command("QuarkdownCompile", function(o) M.compile(o) end, {
    nargs = "*",
    desc = "Compile the current Quarkdown file",
  })
  vim.api.nvim_create_user_command("QuarkdownPreview", function(o) M.preview(o) end, {
    nargs = "*",
    desc = "Compile and live-preview the current Quarkdown file",
  })
  vim.api.nvim_create_user_command("QuarkdownWatch", function(o) M.watch(o) end, {
    nargs = "*",
    desc = "Compile, watch and preview the current Quarkdown file",
  })
  vim.api.nvim_create_user_command("QuarkdownCreate", function(o) M.create(o) end, {
    nargs = "*",
    desc = "Bootstrap a new Quarkdown project",
  })
  vim.api.nvim_create_user_command("QuarkdownStop", function() M.stop() end, {
    desc = "Stop the running Quarkdown background task",
  })
  vim.api.nvim_create_user_command("QuarkdownRestart", function() M.restart_lsp() end, {
    desc = "Restart the Quarkdown language server",
  })

  -- Inline preview controls (no-ops in browser mode).
  vim.api.nvim_create_user_command("QuarkdownPreviewClose", function()
    require("quarkdown.preview").stop()
  end, { desc = "Close the inline Quarkdown preview" })
  vim.api.nvim_create_user_command("QuarkdownPreviewRefresh", function()
    require("quarkdown.preview").refresh()
  end, { desc = "Recompile and refresh the inline preview" })
  vim.api.nvim_create_user_command("QuarkdownPreviewNext", function()
    require("quarkdown.preview").next_page()
  end, { desc = "Show the next page in the inline preview" })
  vim.api.nvim_create_user_command("QuarkdownPreviewPrev", function()
    require("quarkdown.preview").prev_page()
  end, { desc = "Show the previous page in the inline preview" })
  vim.api.nvim_create_user_command("QuarkdownPreviewPage", function(o)
    require("quarkdown.preview").set_page(o.args)
  end, { nargs = 1, desc = "Jump to a specific page in the inline preview" })
end

return M
