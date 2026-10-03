---@diagnostic disable: undefined-field

local parse_slides = require("present")._parse_slides
describe("present.parse_slides", function()
  it("should parse an empty file", function()
    assert.are.same({
      slides = {},
    }, parse_slides({}))
  end)
  it("should parse a file with one slide", function()
    assert.are.same(
      {
        slides = {
          {
            title = "# This is the first slide",
            body = { "This is the body" },
          },
        },
      },
      parse_slides({
        "# This is the first slide",
        "This is the body",
      })
    )
  end)
end)
