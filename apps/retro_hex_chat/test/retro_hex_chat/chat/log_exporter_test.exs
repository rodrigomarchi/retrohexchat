defmodule RetroHexChat.Chat.LogExporterTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.DisplayPreferences
  alias RetroHexChat.Chat.LogExporter
  alias RetroHexChat.Chat.LogFilter

  defp make_entry(nick, content, opts \\ []) do
    %{
      author_nickname: nick,
      content: content,
      type: Keyword.get(opts, :type, "message"),
      inserted_at: Keyword.get(opts, :inserted_at, ~U[2026-01-15 14:30:00Z])
    }
  end

  defp make_pm_entry(sender, content, opts \\ []) do
    %{
      sender_nickname: sender,
      content: content,
      type: Keyword.get(opts, :type, "message"),
      inserted_at: Keyword.get(opts, :inserted_at, ~U[2026-01-15 14:30:00Z])
    }
  end

  defp default_prefs, do: DisplayPreferences.new()

  describe "export/3 with txt format" do
    test "formats regular messages as [timestamp] <Nick> content" do
      entries = [make_entry("Alice", "hello world")]
      result = LogExporter.export(entries, "txt", default_prefs())

      assert result =~ "[14:30:00]"
      assert result =~ "<Alice>"
      assert result =~ "hello world"
    end

    test "formats system messages with asterisk" do
      entries = [make_entry("", "Alice has joined #lobby", type: "system")]
      result = LogExporter.export(entries, "txt", default_prefs())

      assert result =~ "* Alice has joined #lobby"
      refute result =~ "<>"
    end

    test "formats action messages with asterisk and nick" do
      entries = [make_entry("Alice", "waves hello", type: "action")]
      result = LogExporter.export(entries, "txt", default_prefs())

      assert result =~ "* Alice waves hello"
    end

    test "multiple entries separated by newlines" do
      entries = [
        make_entry("Alice", "first"),
        make_entry("Bob", "second")
      ]

      result = LogExporter.export(entries, "txt", default_prefs())
      lines = String.split(result, "\n")
      assert length(lines) == 2
    end

    test "respects timestamp format preference" do
      prefs = DisplayPreferences.set_timestamp_format(default_prefs(), :hh_mm)
      entries = [make_entry("Alice", "hello")]
      result = LogExporter.export(entries, "txt", prefs)

      assert result =~ "[14:30]"
      refute result =~ "[14:30:00]"
    end

    test "filters out system events per preferences" do
      prefs = DisplayPreferences.toggle_event(default_prefs(), :show_joins)

      entries = [
        make_entry("Alice", "hello"),
        make_entry("", "Bob has joined #test", type: "system")
      ]

      result = LogExporter.export(entries, "txt", prefs)

      assert result =~ "hello"
      refute result =~ "joined"
    end

    test "handles PM entries with sender_nickname" do
      entries = [make_pm_entry("Alice", "private message")]
      result = LogExporter.export(entries, "txt", default_prefs())

      assert result =~ "<Alice>"
      assert result =~ "private message"
    end
  end

  describe "export/3 with html format" do
    test "produces standalone HTML document" do
      entries = [make_entry("Alice", "hello")]
      result = LogExporter.export(entries, "html", default_prefs())

      assert result =~ "<!DOCTYPE html>"
      assert result =~ "<html>"
      assert result =~ "</html>"
      assert result =~ "<style>"
    end

    test "includes IRC color CSS classes" do
      entries = [make_entry("Alice", "hello")]
      result = LogExporter.export(entries, "html", default_prefs())

      assert result =~ ".irc-fg-0"
      assert result =~ ".irc-bg-15"
      assert result =~ ".irc-bold"
    end

    test "wraps messages in div elements" do
      entries = [make_entry("Alice", "hello")]
      result = LogExporter.export(entries, "html", default_prefs())

      assert result =~ ~s(<div class="line">)
      assert result =~ ~s(<span class="nick">)
    end

    test "wraps system events with system class" do
      entries = [make_entry("", "Alice has joined", type: "system")]
      result = LogExporter.export(entries, "html", default_prefs())

      assert result =~ ~s(<div class="line system">)
    end

    test "wraps action events with action class" do
      entries = [make_entry("Alice", "waves", type: "action")]
      result = LogExporter.export(entries, "html", default_prefs())

      assert result =~ ~s(<div class="line action">)
    end

    test "escapes HTML special characters in nicknames" do
      entries = [make_entry("<script>", "evil")]
      result = LogExporter.export(entries, "html", default_prefs())

      refute result =~ "<script>"
      assert result =~ "&lt;script&gt;"
    end

    test "filters events per preferences" do
      prefs = DisplayPreferences.toggle_event(default_prefs(), :show_parts)

      entries = [
        make_entry("Alice", "hello"),
        make_entry("", "Bob has left #test", type: "system")
      ]

      result = LogExporter.export(entries, "html", prefs)

      assert result =~ "hello"
      refute result =~ "has left"
    end

    test "uses Formatter.to_safe_html for message content" do
      # Bold formatting code (\x02)
      entries = [make_entry("Alice", "\x02bold text\x02")]
      result = LogExporter.export(entries, "html", default_prefs())

      assert result =~ "irc-bold"
    end
  end

  describe "generate_filename/2" do
    test "strips # from channel name" do
      filter = LogFilter.new(%{source: "#general"})
      assert LogExporter.generate_filename(filter, "txt") == "general.txt"
    end

    test "includes date range when both dates set" do
      filter =
        LogFilter.new(%{source: "#dev", date_from: ~D[2026-01-01], date_to: ~D[2026-01-31]})

      filename = LogExporter.generate_filename(filter, "txt")
      assert filename == "dev_2026-01-01_to_2026-01-31.txt"
    end

    test "includes only date_from when date_to is nil" do
      filter = LogFilter.new(%{source: "#dev", date_from: ~D[2026-01-01]})
      filename = LogExporter.generate_filename(filter, "txt")
      assert filename == "dev_from_2026-01-01.txt"
    end

    test "includes only date_to when date_from is nil" do
      filter = LogFilter.new(%{source: "#dev", date_to: ~D[2026-01-31]})
      filename = LogExporter.generate_filename(filter, "txt")
      assert filename == "dev_to_2026-01-31.txt"
    end

    test "uses .html extension for html format" do
      filter = LogFilter.new(%{source: "#general"})
      assert LogExporter.generate_filename(filter, "html") == "general.html"
    end

    test "uses 'log' as default when no source" do
      filter = LogFilter.new()
      assert LogExporter.generate_filename(filter, "txt") == "log.txt"
    end

    test "handles PM source names" do
      filter = LogFilter.new(%{source: "Alice", source_type: :pm})
      assert LogExporter.generate_filename(filter, "txt") == "Alice.txt"
    end
  end
end
