defmodule RetroHexChat.NicknameCasemapGuardTest do
  @moduledoc """
  Holds the code to one rule for telling nicknames apart: `RetroHexChat.Nickname`.

  A nickname folded anywhere else — a `String.downcase` of its own, a
  `fragment("lower(?)", …)` on a nickname column — is how the app came to have
  thirty-odd private copies of the rule, some folding and some not, and people
  who were one person on one screen and two on another. This reads every source
  file and fails on a new copy. Folding something that is not a nickname (a
  channel name, a word) is fine: only the argument of the fold is inspected.
  """

  use ExUnit.Case, async: true

  @moduletag :unit

  @umbrella Path.expand("../../../..", __DIR__)
  @rule_home "apps/retro_hex_chat/lib/retro_hex_chat/nickname.ex"
  @nickname_like ~r/nick|owner|sender|recipient|founder|tracked|ignored|contact|author|member|peer/i
  @fold ~r/String\.downcase\(([^()]*(?:\([^()]*\))?[^()]*)\)|&String\.downcase\/1|fragment\("lower\(\?\)",\s*([^)]*)\)/

  test "only RetroHexChat.Nickname folds nicknames" do
    copies =
      @umbrella
      |> Path.join("apps/*/lib/**/*.ex")
      |> Path.wildcard()
      |> Enum.reject(&String.ends_with?(&1, @rule_home))
      |> Enum.flat_map(&copies_in/1)

    assert copies == [],
           "fold nicknames through RetroHexChat.Nickname (key/1, equal?/2, matches/2, key_of/1):\n" <>
             Enum.join(copies, "\n")
  end

  test "the guard sees a private copy of the rule" do
    assert copies_in_source("String.downcase(nickname) == String.downcase(other)") != []
    assert copies_in_source(~S|where([n], fragment("lower(?)", n.owner_nickname) == ^x)|) != []
    assert copies_in_source("MapSet.new(nicks, &String.downcase/1)") != []
    assert copies_in_source("String.downcase(channel)") == []
  end

  defp copies_in(path) do
    path
    |> File.read!()
    |> copies_in_source()
    |> Enum.map(fn {line, text} ->
      "#{Path.relative_to(path, @umbrella)}:#{line}: #{String.trim(text)}"
    end)
  end

  defp copies_in_source(source) do
    source
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {text, _line} -> folds_a_nickname?(text) end)
    |> Enum.map(fn {text, line} -> {line, text} end)
  end

  defp folds_a_nickname?(text) do
    @fold
    |> Regex.scan(text)
    |> Enum.any?(fn
      [whole] -> Regex.match?(@nickname_like, text) and whole =~ "&String.downcase/1"
      [_whole | args] -> Enum.any?(args, &Regex.match?(@nickname_like, &1))
    end)
  end
end
