vim.api.nvim_create_user_command("PresentStart", function()
  package.loaded["present"] = nil

  require("present").start_presentation()
end, { desc = "Present a Markdown file as slides" })
