print("loaded present.nvim")
local M = {}

M.setup = function()
  -- nothing, no config
end

local function create_floating_window(config)
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, config)
  return { buf = buf, win = win }
end

---@class present.Slides
---@field slides present.Slide[]: the slides of the file.

---@class present.Slide
---@field title string: the title of the slide.
---@field body string[]: the lines in the buffer.

--- Takes some lines and parses them
---@param lines string[]: The lines in the buffer
---@return present.Slides
local parse_slides = function(lines)
  local slides = { slides = {} }
  local current_slide = nil
  local separator = "^##?%s"
  for _, line in ipairs(lines) do
    if line:find(separator) then
      if current_slide then
        table.insert(slides.slides, current_slide)
      end
      current_slide = {
        title = line,
        body = {},
      }
    elseif current_slide then
      table.insert(current_slide.body, line)
    end
  end
  if current_slide then
    table.insert(slides.slides, current_slide)
  end
  return slides
end

---@return table<string, vim.api.keyset.win_config>
local create_window_configurations = function()
  local width = vim.o.columns
  local height = vim.o.lines
  return {
    background = {
      relative = "editor",
      width = width,
      height = height,
      style = "minimal",
      col = 0,
      row = 0,
      zindex = 1,
    },
    header = {
      relative = "editor",
      width = width,
      height = 1,
      style = "minimal",
      border = "rounded",
      col = 0,
      row = 0,
      zindex = 2,
    },
    body = {
      relative = "editor",
      width = width - 8,
      height = height - 5,
      border = { " ", " ", " ", " ", " ", " ", " ", " " },
      style = "minimal",
      col = 8,
      row = 4,
      zindex = 2,
    },
  }
end

M.start_presentation = function(opts)
  opts = opts or {}
  opts.bufnr = opts.bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
  local parsed = parse_slides(lines)
  local current_slide = 1

  local windows = create_window_configurations()

  local background_float = create_floating_window(windows.background)
  local header_float = create_floating_window(windows.header)
  local body_float = create_floating_window(windows.body)

  vim.bo[header_float.buf].filetype = "markdown"
  vim.bo[body_float.buf].filetype = "markdown"

  local set_slide_content = function(idx)
    local slide = parsed.slides[idx]
    local width = vim.o.columns
    local padding = string.rep(" ", math.floor((width - #slide.title) / 2))
    local title = padding .. slide.title
    vim.api.nvim_buf_set_lines(header_float.buf, 0, -1, false, { title })
    vim.api.nvim_buf_set_lines(body_float.buf, 0, -1, false, slide.body)
  end

  vim.keymap.set("n", "n", function()
    current_slide = math.min(current_slide + 1, #parsed.slides)
    set_slide_content(current_slide)
  end, { buffer = body_float.buf, desc = "go to next slide" })

  vim.keymap.set("n", "p", function()
    current_slide = math.max(current_slide - 1, 1)
    set_slide_content(current_slide)
  end, { buffer = body_float.buf, desc = "go to previous slide" })

  local original_cmdheight = vim.o.cmdheight
  local augroup = vim.api.nvim_create_augroup("present-resized", { clear = true })

  local function cleanup()
    vim.o.cmdheight = original_cmdheight
    pcall(vim.api.nvim_win_close, body_float.win, false)
    pcall(vim.api.nvim_win_close, header_float.win, false)
    pcall(vim.api.nvim_win_close, background_float.win, false)
    pcall(vim.api.nvim_del_augroup_by_id, augroup)
  end

  vim.keymap.set("n", "q", cleanup, { buffer = body_float.buf, desc = "quit slide presentation" })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = body_float.buf,
    callback = cleanup,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = augroup,
    callback = function()
      if not vim.api.nvim_win_is_valid(body_float.win) then
        return
      end
      local updated = create_window_configurations()
      vim.api.nvim_win_set_config(header_float.win, updated.header)
      vim.api.nvim_win_set_config(background_float.win, updated.background)
      vim.api.nvim_win_set_config(body_float.win, updated.body)
      set_slide_content(current_slide)
    end,
  })

  vim.o.cmdheight = 0
  set_slide_content(1)
end

M.start_presentation({
  bufnr = 12,
})

return M
