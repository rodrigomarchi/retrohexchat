#!/usr/bin/env elixir

# Restores showcase <.code_example> blocks from HEAD. Code samples are rendered
# as examples, not application copy, and the broad HEEX wrapper must not rewrite
# escaped markup inside them.

defmodule I18nRestoreCodeExamples do
  @root "apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/showcase_live"
  @block_pattern ~r/<\.code_example(?:\s[^>]*)?>.*?<\/\.code_example>/su

  def run do
    files =
      @root
      |> Path.join("**/*.{ex,heex}")
      |> Path.wildcard()
      |> Enum.sort()

    restored =
      Enum.reduce(files, 0, fn file, count ->
        current = File.read!(file)

        if String.contains?(current, "<.code_example") do
          case head_file(file) do
            {:ok, head} -> maybe_restore(file, current, head, count)
            :error -> count
          end
        else
          count
        end
      end)

    IO.puts("restored=#{restored} scanned=#{length(files)}")
  end

  defp maybe_restore(file, current, head, count) do
    current_blocks = Regex.scan(@block_pattern, current) |> List.flatten()
    head_blocks = Regex.scan(@block_pattern, head) |> List.flatten()

    cond do
      current_blocks == [] ->
        count

      length(current_blocks) != length(head_blocks) ->
        IO.puts(:stderr, "Skipping #{file}: block count changed")
        count

      not Enum.any?(current_blocks, &String.contains?(&1, "gettext(")) ->
        count

      true ->
        {updated, _} =
          Enum.reduce(current_blocks, {current, head_blocks}, fn current_block,
                                                                 {source, [head_block | rest]} ->
            replacement =
              if String.contains?(current_block, "gettext(") do
                head_block
              else
                current_block
              end

            {String.replace(source, current_block, replacement, global: false), rest}
          end)

        if updated != current do
          File.write!(file, updated)
          count + 1
        else
          count
        end
    end
  end

  defp head_file(file) do
    case System.cmd("git", ["show", "HEAD:#{file}"], stderr_to_stdout: true) do
      {content, 0} -> {:ok, content}
      {_error, _status} -> :error
    end
  end
end

I18nRestoreCodeExamples.run()
