defmodule RetroHexChat.Chat.LogFilterTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.LogFilter

  describe "new/0" do
    test "returns a filter with default values" do
      filter = LogFilter.new()

      assert filter.source == nil
      assert filter.source_type == :channel
      assert filter.date_from == nil
      assert filter.date_to == nil
      assert filter.nickname == nil
      assert filter.text == nil
      assert filter.page == 1
      assert filter.per_page == 50
    end
  end

  describe "new/1" do
    test "creates filter with provided attributes" do
      today = Date.utc_today()

      filter =
        LogFilter.new(%{
          source: "#lobby",
          source_type: :channel,
          date_from: ~D[2026-01-01],
          date_to: today,
          nickname: "Alice",
          text: "hello",
          page: 3
        })

      assert filter.source == "#lobby"
      assert filter.source_type == :channel
      assert filter.date_from == ~D[2026-01-01]
      assert filter.date_to == today
      assert filter.nickname == "Alice"
      assert filter.text == "hello"
      assert filter.page == 3
      assert filter.per_page == 50
    end

    test "ignores unknown keys" do
      filter = LogFilter.new(%{source: "#test", unknown_key: "ignored"})

      assert filter.source == "#test"
      assert filter.page == 1
    end

    test "forces per_page to 50 even if provided" do
      filter = LogFilter.new(%{per_page: 100})

      assert filter.per_page == 50
    end

    test "uses defaults for unspecified fields" do
      filter = LogFilter.new(%{source: "#general"})

      assert filter.source == "#general"
      assert filter.source_type == :channel
      assert filter.date_from == nil
      assert filter.date_to == nil
      assert filter.nickname == nil
      assert filter.text == nil
      assert filter.page == 1
      assert filter.per_page == 50
    end

    test "accepts :pm source_type" do
      filter = LogFilter.new(%{source_type: :pm})

      assert filter.source_type == :pm
    end
  end

  describe "validate/1" do
    test "returns :ok for default filter" do
      assert :ok == LogFilter.validate(LogFilter.new())
    end

    test "returns :ok for valid filter with all fields set" do
      filter =
        LogFilter.new(%{
          source: "#lobby",
          source_type: :channel,
          date_from: ~D[2026-01-01],
          date_to: Date.utc_today(),
          nickname: "Bob",
          text: "search term",
          page: 5
        })

      assert :ok == LogFilter.validate(filter)
    end

    test "returns :ok when date_from equals date_to" do
      today = Date.utc_today()

      filter = LogFilter.new(%{date_from: today, date_to: today})

      assert :ok == LogFilter.validate(filter)
    end

    test "returns :ok when only date_from is set" do
      filter = LogFilter.new(%{date_from: ~D[2026-01-01]})

      assert :ok == LogFilter.validate(filter)
    end

    test "returns :ok when only date_to is set" do
      filter = LogFilter.new(%{date_to: Date.utc_today()})

      assert :ok == LogFilter.validate(filter)
    end

    test "returns error when date_from is in the future" do
      future = Date.add(Date.utc_today(), 1)
      filter = LogFilter.new(%{date_from: future})

      assert {:error, "date_from must not be in the future"} == LogFilter.validate(filter)
    end

    test "returns error when date_to is in the future" do
      future = Date.add(Date.utc_today(), 1)
      filter = LogFilter.new(%{date_to: future})

      assert {:error, "date_to must not be in the future"} == LogFilter.validate(filter)
    end

    test "returns error when date_from is after date_to" do
      filter = LogFilter.new(%{date_from: ~D[2026-01-15], date_to: ~D[2026-01-10]})

      assert {:error, "date_from must not be after date_to"} == LogFilter.validate(filter)
    end

    test "returns error when page is 0" do
      filter = %{LogFilter.new() | page: 0}

      assert {:error, "page must be >= 1"} == LogFilter.validate(filter)
    end

    test "returns error when page is negative" do
      filter = %{LogFilter.new() | page: -1}

      assert {:error, "page must be >= 1"} == LogFilter.validate(filter)
    end

    test "returns error when per_page is not 50" do
      filter = %{LogFilter.new() | per_page: 25}

      assert {:error, "per_page must be 50"} == LogFilter.validate(filter)
    end

    test "returns first error encountered (page before dates)" do
      future = Date.add(Date.utc_today(), 1)
      filter = %{LogFilter.new(%{date_from: future}) | page: 0}

      # page is validated first
      assert {:error, "page must be >= 1"} == LogFilter.validate(filter)
    end
  end

  describe "escape_text/1" do
    test "escapes asterisk" do
      assert LogFilter.escape_text("hello*world") == "hello\\*world"
    end

    test "escapes plus" do
      assert LogFilter.escape_text("a+b") == "a\\+b"
    end

    test "escapes question mark" do
      assert LogFilter.escape_text("why?") == "why\\?"
    end

    test "escapes dot" do
      assert LogFilter.escape_text("file.txt") == "file\\.txt"
    end

    test "escapes parentheses" do
      assert LogFilter.escape_text("(group)") == "\\(group\\)"
    end

    test "escapes square brackets" do
      assert LogFilter.escape_text("[a]") == "\\[a\\]"
    end

    test "escapes curly braces" do
      assert LogFilter.escape_text("{n}") == "\\{n\\}"
    end

    test "escapes backslash" do
      assert LogFilter.escape_text("a\\b") == "a\\\\b"
    end

    test "escapes caret" do
      assert LogFilter.escape_text("^start") == "\\^start"
    end

    test "escapes dollar sign" do
      assert LogFilter.escape_text("end$") == "end\\$"
    end

    test "escapes pipe" do
      assert LogFilter.escape_text("a|b") == "a\\|b"
    end

    test "escapes percent (LIKE wildcard)" do
      assert LogFilter.escape_text("100%") == "100\\%"
    end

    test "escapes underscore (LIKE wildcard)" do
      assert LogFilter.escape_text("some_var") == "some\\_var"
    end

    test "leaves plain text unchanged" do
      assert LogFilter.escape_text("hello world") == "hello world"
    end

    test "escapes multiple metacharacters in one string" do
      assert LogFilter.escape_text("a.b*c?d") == "a\\.b\\*c\\?d"
    end

    test "handles empty string" do
      assert LogFilter.escape_text("") == ""
    end

    test "escapes all metacharacters at once" do
      input = "*+?.()[]{}\\^$|%_"
      expected = "\\*\\+\\?\\.\\(\\)\\[\\]\\{\\}\\\\\\^\\$\\|\\%\\_"
      assert LogFilter.escape_text(input) == expected
    end
  end
end
