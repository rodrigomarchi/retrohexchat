defmodule RetroHexChat.Chat.TimeFormatterTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.TimeFormatter

  describe "format_duration/1" do
    test "0 seconds returns less than a minute" do
      assert TimeFormatter.format_duration(0) == "less than a minute"
    end

    test "59 seconds returns less than a minute" do
      assert TimeFormatter.format_duration(59) == "less than a minute"
    end

    test "60 seconds returns 1 minute" do
      assert TimeFormatter.format_duration(60) == "1 minute"
    end

    test "120 seconds returns 2 minutes" do
      assert TimeFormatter.format_duration(120) == "2 minutes"
    end

    test "3600 seconds returns 1 hour" do
      assert TimeFormatter.format_duration(3600) == "1 hour"
    end

    test "3660 seconds returns 1 hour 1 minute" do
      assert TimeFormatter.format_duration(3660) == "1 hour 1 minute"
    end

    test "7200 seconds returns 2 hours" do
      assert TimeFormatter.format_duration(7200) == "2 hours"
    end

    test "8100 seconds returns 2 hours 15 minutes" do
      assert TimeFormatter.format_duration(8100) == "2 hours 15 minutes"
    end

    test "1 second returns less than a minute" do
      assert TimeFormatter.format_duration(1) == "less than a minute"
    end

    test "large value (86400) returns 24 hours" do
      assert TimeFormatter.format_duration(86_400) == "24 hours"
    end
  end

  describe "format_relative/1" do
    test "recent timestamp returns X ago" do
      past = DateTime.add(DateTime.utc_now(), -3600, :second)
      result = TimeFormatter.format_relative(past)
      assert result =~ "1 hour ago"
    end

    test "very recent timestamp returns less than a minute ago" do
      result = TimeFormatter.format_relative(DateTime.utc_now())
      assert result == "less than a minute ago"
    end

    test "future timestamp returns just now" do
      future = DateTime.add(DateTime.utc_now(), 60, :second)
      result = TimeFormatter.format_relative(future)
      assert result == "just now"
    end
  end
end
