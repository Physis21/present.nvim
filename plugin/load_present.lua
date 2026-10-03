vim.api.nvim_create_user_command("PresentStart", function()
  package.loaded["present"] = nil

  -- requiring the plugin here makes it lazy loaded
  -- Thus the user doesn't have to think about lazy loading the plugin.
  require("present").start_presentation()
end, { desc = "Present a Markdown file as slides" })
