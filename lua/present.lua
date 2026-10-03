print("loaded present.nvim")
local M = {}

M.setup = function()
  -- nothing, no config
end

---@class present.Float
---@field buf integer the buffer id
---@field win integer the window id

---@param config vim.api.keyset.win_config
---@param enter? boolean defaults to false
---@return present.Float
local function create_floating_window(config, enter)
  enter = enter or false
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, enter, config)
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
  local header_height = 1 + 2 -- 1 + border
  local footer_height = 1 -- 1, no border
  local body_height = height - header_height - footer_height - 2 - 1
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
      height = body_height,
      border = { " ", " ", " ", " ", " ", " ", " ", " " },
      style = "minimal",
      col = 8,
      row = 4,
      zindex = 2,
    },
    footer = {
      relative = "editor",
      width = width,
      height = 1,
      style = "minimal",
      -- border = "rounded", -- TODO: just a border on the top?
      col = 0,
      row = height - 1,
      zindex = 3,
    },
  }
end

local state = {
  parsed = {},
  current_slide = 1,
  ---@type present.Float[]
  floats = {},
}

---@param cb fun(string, present.Float) a callback taking the float name and id
local foreach_float = function(cb)
  for name, float in pairs(state.floats) do
    cb(name, float)
  end
end

---@param mode string
---@param key string
---@param callback function
---@param desc string
local present_keymap = function(mode, key, callback, desc)
  desc = desc or ""
  vim.keymap.set(mode, key, callback, {
    buffer = state.floats.body.buf,
    desc = desc,
  })
end

M.start_presentation = function(opts)
  opts = opts or {}
  opts.bufnr = opts.bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
  state.parsed = parse_slides(lines)
  state.current_slide = 1
  state.title = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(opts.bufnr), ":t") -- :t is tail

  local windows = create_window_configurations()

  state.floats["background"] = create_floating_window(windows.background)
  state.floats["header"] = create_floating_window(windows.header)
  state.floats["body"] = create_floating_window(windows.body, true)
  state.floats["footer"] = create_floating_window(windows.footer)

  foreach_float(
    ---@param float present.Float
    function(_, float)
      vim.bo[float.buf].filetype = "markdown"
    end
  )

  ---@param slide_idx integer
  local function set_slide_content(slide_idx)
    local slide = state.parsed.slides[slide_idx]
    local width = vim.o.columns
    local padding = string.rep(" ", math.floor((width - #slide.title) / 2))
    local title = padding .. slide.title
    vim.api.nvim_buf_set_lines(state.floats.header.buf, 0, -1, false, { title })
    vim.api.nvim_buf_set_lines(state.floats.body.buf, 0, -1, false, slide.body)

    local footer = string.format("  %d / %d | %s", state.current_slide, #state.parsed.slides, state.title)
    vim.api.nvim_buf_set_lines(state.floats.footer.buf, 0, -1, false, { footer })
  end

  present_keymap("n", "n", function()
    state.current_slide = math.min(state.current_slide + 1, #state.parsed.slides)
    set_slide_content(state.current_slide)
  end, "go to next slide")

  present_keymap("n", "p", function()
    state.current_slide = math.max(state.current_slide - 1, 1)
    set_slide_content(state.current_slide)
  end, "go to previous slide")

  local augroup = vim.api.nvim_create_augroup("present-resized", { clear = true })

  local restore = {
    cmdheight = {
      original = vim.o.cmdheight,
      present = 0,
    },
  }

  local function cleanup()
    for option, config in pairs(restore) do
      vim.opt[option] = config.original
    end

    foreach_float(function(_, float)
      pcall(vim.api.nvim_win_close, float.win, false)
    end)
    pcall(vim.api.nvim_del_augroup_by_id, augroup)
  end

  present_keymap("n", "q", cleanup, "quit slide presentation")

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = state.floats.body.buf,
    callback = cleanup,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = augroup,
    callback = function()
      if not vim.api.nvim_win_is_valid(state.floats.body.win) then
        return
      end
      local updated = create_window_configurations()
      foreach_float(function(name, _)
        vim.api.nvim_win_set_config(state.floats[name].win, updated[name])
      end)
      set_slide_content(state.current_slide)
    end,
  })

  vim.o.cmdheight = 0
  set_slide_content(1)
end

M._parse_slides = parse_slides

return M
