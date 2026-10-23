defmodule RetroHexChatWeb.Components.SpacingTokensTest do
  @moduledoc """
  Every `*-retro-N` class names a step the spacing scale has.

  Tailwind generates nothing for a class it has no value for, and says
  nothing either: `gap-retro-3` read as a three-pixel gap to whoever wrote it
  and drew no gap at all, so every trusted-terminal fact had its label glued
  to its value. The scale lives in `assets/tailwind.config.js`; this reads it
  and the sources that use it.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  @root Path.expand("../../..", __DIR__)
  @config Path.join(@root, "assets/tailwind.config.js")
  @sources ["lib/**/*.{ex,heex}", "assets/js/**/*.js", "assets/css/retrohex/**/*.css"]

  test "no class names a spacing step the scale does not have" do
    steps = scale_steps()
    assert steps != [], "found no retro-N steps in #{@config}"

    unknown =
      for pattern <- @sources,
          path <- Path.wildcard(Path.join(@root, pattern)),
          {line, number} <- Enum.with_index(File.stream!(path), 1),
          [class, step] <- Regex.scan(~r/\b[a-z][\w:-]*?-retro-(\d+)\b/, line),
          step not in steps do
        "#{Path.relative_to(path, @root)}:#{number} #{class}"
      end

    assert unknown == [],
           "these classes name no step of the spacing scale (#{Enum.join(steps, ", ")}):\n" <>
             Enum.join(unknown, "\n")
  end

  defp scale_steps do
    ~r/"retro-(\d+)":\s*"\d+px"/
    |> Regex.scan(File.read!(@config))
    |> Enum.map(fn [_match, step] -> step end)
  end
end
