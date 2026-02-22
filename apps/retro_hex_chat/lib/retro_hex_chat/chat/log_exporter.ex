defmodule RetroHexChat.Chat.LogExporter do
  @moduledoc """
  Exports chat log entries as plain text (.txt) or styled HTML (.html).
  Respects DisplayPreferences for event filtering and timestamp format.
  """

  alias RetroHexChat.Chat.DisplayPreferences
  alias RetroHexChat.Chat.Formatter
  alias RetroHexChat.Chat.LogFilter

  @spec export(list(map()), String.t(), DisplayPreferences.t(), String.t()) :: String.t()
  def export(entries, format, prefs, timezone \\ "Etc/UTC") do
    filtered = filter_by_preferences(entries, prefs)

    case format do
      "txt" -> export_txt(filtered, prefs, timezone)
      "html" -> export_html(filtered, prefs, timezone)
    end
  end

  @spec generate_filename(LogFilter.t(), String.t()) :: String.t()
  def generate_filename(%LogFilter{} = filter, format) do
    source_part = format_source(filter.source, filter.source_type)
    date_part = format_date_range(filter.date_from, filter.date_to)
    ext = if format == "html", do: ".html", else: ".txt"

    parts = [source_part, date_part] |> Enum.reject(&is_nil/1)
    base = Enum.join(parts, "_")
    base = if base == "", do: "log", else: base

    base <> ext
  end

  # Private

  defp filter_by_preferences(entries, prefs) do
    Enum.filter(entries, fn entry ->
      type = Map.get(entry, :type, "message")
      content = Map.get(entry, :content, "")
      DisplayPreferences.visible_type?(prefs, type, content)
    end)
  end

  defp export_txt(entries, prefs, timezone) do
    entries
    |> Enum.map(fn entry -> format_txt_line(entry, prefs, timezone) end)
    |> Enum.join("\n")
  end

  defp format_txt_line(entry, prefs, timezone) do
    ts = format_timestamp(entry, prefs, timezone)
    type = Map.get(entry, :type, "message")
    content = Map.get(entry, :content, "")

    case type do
      "system" ->
        "#{ts} * #{content}"

      "action" ->
        nick = get_nick(entry)
        "#{ts} * #{nick} #{content}"

      _ ->
        nick = get_nick(entry)
        "#{ts} <#{nick}> #{content}"
    end
  end

  defp export_html(entries, prefs, timezone) do
    body =
      entries
      |> Enum.map(fn entry -> format_html_line(entry, prefs, timezone) end)
      |> Enum.join("\n")

    """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <title>Chat Log</title>
    <style>
    body { font-family: 'Courier New', Courier, monospace; font-size: 12px; background: #fff; color: #000; padding: 8px; }
    .timestamp { color: #808080; }
    .nick { font-weight: bold; }
    .system { color: #808080; font-style: italic; }
    .action { color: #808080; }
    .line { padding: 1px 0; }
    .irc-bold { font-weight: bold; }
    .irc-italic { font-style: italic; }
    .irc-underline { text-decoration: underline; }
    .irc-fg-0 { color: #ffffff; } .irc-fg-1 { color: #000000; } .irc-fg-2 { color: #00007f; }
    .irc-fg-3 { color: #009300; } .irc-fg-4 { color: #ff0000; } .irc-fg-5 { color: #7f0000; }
    .irc-fg-6 { color: #9c009c; } .irc-fg-7 { color: #fc7f00; } .irc-fg-8 { color: #ffff00; }
    .irc-fg-9 { color: #00fc00; } .irc-fg-10 { color: #009393; } .irc-fg-11 { color: #00ffff; }
    .irc-fg-12 { color: #0000fc; } .irc-fg-13 { color: #ff00ff; } .irc-fg-14 { color: #7f7f7f; }
    .irc-fg-15 { color: #d2d2d2; }
    .irc-bg-0 { background: #ffffff; } .irc-bg-1 { background: #000000; } .irc-bg-2 { background: #00007f; }
    .irc-bg-3 { background: #009300; } .irc-bg-4 { background: #ff0000; } .irc-bg-5 { background: #7f0000; }
    .irc-bg-6 { background: #9c009c; } .irc-bg-7 { background: #fc7f00; } .irc-bg-8 { background: #ffff00; }
    .irc-bg-9 { background: #00fc00; } .irc-bg-10 { background: #009393; } .irc-bg-11 { background: #00ffff; }
    .irc-bg-12 { background: #0000fc; } .irc-bg-13 { background: #ff00ff; } .irc-bg-14 { background: #7f7f7f; }
    .irc-bg-15 { background: #d2d2d2; }
    </style>
    </head>
    <body>
    #{body}
    </body>
    </html>
    """
  end

  defp format_html_line(entry, prefs, timezone) do
    ts = format_timestamp(entry, prefs, timezone)
    type = Map.get(entry, :type, "message")
    content = Map.get(entry, :content, "")

    case type do
      "system" ->
        escaped = Phoenix.HTML.html_escape(content) |> Phoenix.HTML.safe_to_string()
        ~s(<div class="line system"><span class="timestamp">#{ts}</span> * #{escaped}</div>)

      "action" ->
        nick = get_nick(entry)
        {:safe, html} = Formatter.to_safe_html(content)

        ~s(<div class="line action"><span class="timestamp">#{ts}</span> * <span class="nick">#{escape(nick)}</span> #{html}</div>)

      _ ->
        nick = get_nick(entry)
        {:safe, html} = Formatter.to_safe_html(content)

        ~s(<div class="line"><span class="timestamp">#{ts}</span> &lt;<span class="nick">#{escape(nick)}</span>&gt; #{html}</div>)
    end
  end

  defp format_timestamp(entry, prefs, timezone) do
    ts = Map.get(entry, :inserted_at)

    if ts do
      shifted = shift_timezone(ts, timezone)
      DisplayPreferences.format_timestamp(prefs, shifted)
    else
      ""
    end
  end

  defp shift_timezone(%DateTime{} = dt, "Etc/UTC"), do: dt

  defp shift_timezone(%DateTime{} = dt, timezone) do
    case DateTime.shift_zone(dt, timezone) do
      {:ok, shifted} -> shifted
      {:error, _} -> dt
    end
  end

  defp shift_timezone(dt, _timezone), do: dt

  defp get_nick(entry) do
    Map.get(entry, :author_nickname) || Map.get(entry, :sender_nickname, "")
  end

  defp escape(text) do
    Phoenix.HTML.html_escape(text) |> Phoenix.HTML.safe_to_string()
  end

  defp format_source(nil, _type), do: nil

  defp format_source(source, _type) do
    source
    |> String.replace("#", "")
    |> String.replace(~r/[^a-zA-Z0-9_-]/, "_")
  end

  defp format_date_range(nil, nil), do: nil

  defp format_date_range(from, nil) do
    "from_#{Date.to_iso8601(from)}"
  end

  defp format_date_range(nil, to) do
    "to_#{Date.to_iso8601(to)}"
  end

  defp format_date_range(from, to) do
    "#{Date.to_iso8601(from)}_to_#{Date.to_iso8601(to)}"
  end
end
