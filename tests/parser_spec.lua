local parser = require("bujo.parser")

describe("parser", function()
  describe("parse_line", function()
    local parser_cases = {
      { "• buy milk", "task", "open", "buy milk" },
      { "× call mom", "task", "done", "call mom" },
      { "› fix bike", "task", "migrated", "fix bike" },
      { "~• cancelled thing", "task", "cancelled", "cancelled thing" },
      { "– coffee was good", "note", "open", "coffee was good" },
      { "▽ standup 10am", "event", "open", "standup 10am" },
      { "▷ dentist next tue", "future", "open", "dentist next tue" },
      { "~▽ standup", "event", "cancelled", "standup" },
      { "~▷ dentist", "future", "cancelled", "dentist" },
      { "•  two spaces ", "task", "open", " two spaces " },
    }
    for _, c in ipairs(parser_cases) do
      it("parses " .. c[1], function()
        assert.are.same({ kind = c[2], state = c[3], text = c[4] }, parser.parse_line(c[1]))
      end)
    end

    it("coerces a missing space and a leading asterisk", function()
      local coerced_cases = {
        { "•buy milk", "task", "open", "buy milk" },
        { "×done", "task", "done", "done" },
        { "▽standup", "event", "open", "standup" },
        { "~•gone", "task", "cancelled", "gone" },
        { "* buy milk", "task", "open", "buy milk" },
        { "*buy milk", "task", "open", "buy milk" },
        { "~* gone", "task", "cancelled", "gone" },
      }
      for _, c in ipairs(coerced_cases) do
        assert.are.same({ kind = c[2], state = c[3], text = c[4] }, parser.parse_line(c[1]), c[1])
      end
      assert.are.equal("• buy milk", parser.serialize_line(parser.parse_line("*buy milk")))
    end)

    it("returns empty entries; dropping them is left to parse", function()
      for _, line in ipairs({ "•", "• " }) do
        assert.are.same({ kind = "task", state = "open", text = "" }, parser.parse_line(line), line)
      end
    end)

    it("keeps unrecognised lines as raw", function()
      local lines = { "", "plain text", "**bold**", "~– note", "~× done", "~plain" }
      for _, line in ipairs(lines) do
        assert.are.same({ kind = "raw", state = "open", text = line }, parser.parse_line(line))
      end
    end)
  end)

  it("serialize_line round-trips every line", function()
    local lines = { "• a", "× b", "› c", "~• d", "– e", "▽ f", "▷ g", "~▽ h", "~▷ i", "", "free", "~– n" }
    for _, line in ipairs(lines) do
      assert.are.equal(line, parser.serialize_line(parser.parse_line(line)))
    end
  end)

  describe("parse / serialize", function()
    it("round-trips a whole file", function()
      local content = "• buy milk\n× call mom\n\nfree text\n~▽ standup\n"
      assert.are.equal(content, parser.serialize(parser.parse(content)))
    end)

    it("handles CRLF and a missing trailing newline", function()
      local entries = parser.parse("• a\r\n– b")
      assert.are.equal(2, #entries)
      assert.are.equal("b", entries[2].text)
      assert.are.equal("• a\n– b\n", parser.serialize(entries))
    end)

    it("drops empty entries but keeps blank raw lines", function()
      local content = "•\n• a\n*\n~•  \n× \n–\n▽ \n~▷\n\n– b\n"
      assert.are.equal("• a\n\n– b\n", parser.serialize(parser.parse(content)))
    end)

    it("treats empty content as no entries", function()
      assert.are.same({}, parser.parse(""))
      assert.are.equal("", parser.serialize({}))
    end)
  end)
end)
