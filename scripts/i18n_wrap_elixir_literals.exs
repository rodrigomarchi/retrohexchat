#!/usr/bin/env elixir

defmodule I18nWrapElixirLiterals do
  @moduledoc false

  @double_string ~r/"(?:\\.|[^"\\])*"/u

  @excluded_paths [
    "apps/retro_hex_chat/lib/retro_hex_chat/chat/emoji_data.ex",
    "apps/retro_hex_chat/lib/retro_hex_chat/arcade/catalog.ex",
    "apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex",
    "apps/retro_hex_chat/lib/retro_hex_chat/chat/key_bindings.ex",
    "apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex",
    "apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/showcase_helpers.ex",
    "apps/retro_hex_chat_web/lib/retro_hex_chat_web/router.ex"
  ]

  def main(args) do
    audit_path = System.get_env("I18N_AUDIT_JSON") || List.first(args) || usage!()
    audit = audit_path |> File.read!() |> Jason.decode!()

    findings =
      audit["findings"]
      |> Enum.filter(&wrap_candidate?/1)
      |> Enum.group_by(& &1["path"])

    rewritten =
      Enum.reduce(findings, 0, fn {path, path_findings}, count ->
        source = File.read!(path)
        updated = rewrite_file(path, source, path_findings)

        if updated != source do
          File.write!(path, updated)
          count + 1
        else
          count
        end
      end)

    IO.puts("rewritten=#{rewritten} scanned=#{map_size(findings)}")
  end

  defp usage! do
    IO.puts(
      :stderr,
      "Usage: I18N_AUDIT_JSON=/tmp/audit.json elixir scripts/i18n_wrap_elixir_literals.exs"
    )

    System.halt(2)
  end

  defp wrap_candidate?(%{"kind" => "elixir_literal", "path" => path, "text" => text}) do
    Path.extname(path) == ".ex" and
      path not in @excluded_paths and
      not String.contains?(path, "/lib/mix/tasks/") and
      not String.contains?(text, "\#{") and
      not String.contains?(text, "%{")
  end

  defp wrap_candidate?(_finding), do: false

  defp rewrite_file(path, source, findings) do
    targets_by_line =
      findings
      |> Enum.group_by(& &1["line"], & &1["text"])
      |> Map.new(fn {line, texts} -> {line, MapSet.new(texts)} end)

    lines = String.split(source, "\n", trim: false)

    {updated_lines, changed?} =
      lines
      |> Enum.with_index(1)
      |> Enum.map_reduce(false, fn {line, line_no}, changed? ->
        targets = Map.get(targets_by_line, line_no, MapSet.new())

        if MapSet.size(targets) == 0 do
          {line, changed?}
        else
          updated = rewrite_line(line, targets)
          {updated, changed? or updated != line}
        end
      end)

    updated = Enum.join(updated_lines, "\n")

    if changed? do
      ensure_gettext(path, updated)
    else
      source
    end
  end

  defp rewrite_line(line, targets) do
    matches = Regex.scan(@double_string, line, return: :index) |> List.flatten()

    matches
    |> Enum.reverse()
    |> Enum.reduce(line, fn {start, len}, acc ->
      raw = binary_part(acc, start, len)
      text = raw |> unquote_string() |> cleanup_text()

      if MapSet.member?(targets, text) and not already_wrapped?(acc, start) do
        replace_at(acc, start, len, "gettext(#{raw})")
      else
        acc
      end
    end)
  end

  defp already_wrapped?(line, start) do
    prefix = binary_part(line, 0, start)

    Regex.match?(
      ~r/(?:gettext|dgettext|ngettext|dngettext|pgettext|dpgettext)\s*\([^()\n]*$/u,
      prefix
    )
  end

  defp replace_at(line, start, len, replacement) do
    <<before::binary-size(start), _old::binary-size(len), after_part::binary>> = line
    before <> replacement <> after_part
  end

  defp ensure_gettext(path, source) do
    cond do
      String.contains?(source, "use Gettext") ->
        source

      String.starts_with?(path, "apps/retro_hex_chat_web/") and
          (String.contains?(source, "use RetroHexChatWeb") or
             String.contains?(source, "use RetroHexChatWeb.Component")) ->
        source

      true ->
        backend =
          if String.starts_with?(path, "apps/retro_hex_chat_web/"),
            do: "RetroHexChatWeb.Gettext",
            else: "RetroHexChat.Gettext"

        insert_use_gettext(source, backend)
    end
  end

  defp insert_use_gettext(source, backend) do
    lines = String.split(source, "\n", trim: false)
    insert_at = gettext_insert_index(lines)
    List.insert_at(lines, insert_at, "  use Gettext, backend: #{backend}") |> Enum.join("\n")
  end

  defp gettext_insert_index(lines) do
    moduledoc_start = Enum.find_index(lines, &String.contains?(&1, "@moduledoc"))

    cond do
      is_nil(moduledoc_start) ->
        case Enum.find_index(lines, &Regex.match?(~r/^defmodule\b/, &1)) do
          nil -> 0
          index -> index + 1
        end

      String.contains?(Enum.at(lines, moduledoc_start), ~s(""")) ->
        lines
        |> Enum.with_index()
        |> Enum.drop(moduledoc_start + 1)
        |> Enum.find_value(moduledoc_start + 1, fn {line, index} ->
          if String.contains?(line, ~s(""")), do: index + 1
        end)

      true ->
        moduledoc_start + 1
    end
  end

  defp unquote_string(raw) do
    raw
    |> String.slice(1, String.length(raw) - 2)
    |> String.replace("\\\"", "\"")
    |> String.replace("\\n", " ")
    |> String.replace("\\'", "'")
  end

  defp cleanup_text(text) do
    text
    |> String.trim()
    |> String.replace(~r/\s+/u, " ")
  end
end

I18nWrapElixirLiterals.main(System.argv())
