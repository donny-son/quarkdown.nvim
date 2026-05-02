local M = {}

local function report_start(name)
  if vim.health and vim.health.start then
    vim.health.start(name)
  else
    vim.health.report_start(name)
  end
end

local function report_ok(msg)
  if vim.health and vim.health.ok then
    vim.health.ok(msg)
  else
    vim.health.report_ok(msg)
  end
end

local function report_warn(msg, advice)
  if vim.health and vim.health.warn then
    vim.health.warn(msg, advice)
  else
    vim.health.report_warn(msg, advice)
  end
end

local function report_error(msg, advice)
  if vim.health and vim.health.error then
    vim.health.error(msg, advice)
  else
    vim.health.report_error(msg, advice)
  end
end

function M.check()
  local config = require("quarkdown.config")
  report_start("quarkdown.nvim")

  local cmd = config.options.cmd or { "quarkdown" }
  local exe = cmd[1]
  if vim.fn.executable(exe) == 1 then
    report_ok(("`%s` found at %s"):format(exe, vim.fn.exepath(exe)))
  else
    report_error(("`%s` not found on PATH"):format(exe), {
      "Install Quarkdown and ensure the binary is on PATH.",
      "See https://github.com/iamgio/quarkdown for installation instructions.",
    })
    return
  end

  local version = vim.fn.system({ exe, "--version" })
  if vim.v.shell_error == 0 then
    report_ok("quarkdown version: " .. vim.trim(version))
  else
    report_warn("could not read quarkdown version")
  end

  if vim.fn.has("nvim-0.10") == 1 then
    report_ok("Neovim >= 0.10 detected")
  else
    report_warn("Neovim 0.10+ recommended for the modern vim.lsp.start API")
  end
end

return M
