defmodule RetroHexChat.Commands.Parser do
  @moduledoc """
  Parses raw input into commands or plain messages.
  """

  @spec parse(String.t()) :: {:command, String.t(), [String.t()]} | {:message, String.t()}
  def parse(text) do
    leading_trimmed = String.trim_leading(text)

    cond do
      leading_trimmed == "" ->
        {:message, text}

      String.starts_with?(leading_trimmed, "//") ->
        {:message, text}

      String.starts_with?(leading_trimmed, "/") ->
        parse_command(leading_trimmed)

      true ->
        {:message, text}
    end
  end

  defp parse_command("/" <> rest) do
    case Regex.run(~r/^([^\s]*)(?:\s*(.*))?$/s, rest, capture: :all_but_first) do
      [""] ->
        {:command, "", []}

      [cmd] ->
        {:command, String.downcase(cmd), []}

      [cmd, raw_args] ->
        command = String.downcase(cmd)
        {:command, command, parse_args(command, raw_args)}
    end
  end

  defp parse_args(_command, ""), do: []

  defp parse_args(command, raw_args) do
    cond do
      command in ~w(announce away bio me quit setmotd setwelcome topic wallops) ->
        preserved_args(raw_args, 0)

      command in ~w(ban kick knock msg notice notify part) ->
        parse_command_with_preserved_rest(command, raw_args)

      command in ~w(alias autojoin autorespond bot perform timer) ->
        parse_structured_command(command, raw_args)

      true ->
        split_args(raw_args)
    end
  end

  defp parse_command_with_preserved_rest("notify", raw_args) do
    case split_args(raw_args) do
      ["add" | _] -> preserved_args(raw_args, 2)
      ["edit" | _] -> preserved_args(raw_args, 2)
      _ -> split_args(raw_args)
    end
  end

  defp parse_command_with_preserved_rest("part", raw_args) do
    case split_args(raw_args) do
      [first | _] ->
        if String.starts_with?(first, "#") do
          preserved_args(raw_args, 1)
        else
          preserved_args(raw_args, 0)
        end

      _ ->
        preserved_args(raw_args, 1)
    end
  end

  defp parse_command_with_preserved_rest(_command, raw_args), do: preserved_args(raw_args, 1)

  defp parse_structured_command("alias", raw_args) do
    case split_args(raw_args) do
      ["add" | _] -> preserved_args(raw_args, 2)
      _ -> split_args(raw_args)
    end
  end

  defp parse_structured_command("autojoin", raw_args) do
    case split_args(raw_args) do
      ["add" | _] -> preserved_args(raw_args, 2)
      _ -> split_args(raw_args)
    end
  end

  defp parse_structured_command("autorespond", raw_args) do
    case split_args(raw_args) do
      ["add", _trigger, "#" <> _channel | _] -> preserved_args(raw_args, 3)
      ["add" | _] -> preserved_args(raw_args, 2)
      _ -> split_args(raw_args)
    end
  end

  defp parse_structured_command("bot", raw_args) do
    case split_args(raw_args) do
      ["create" | _] -> preserved_args(raw_args, 2)
      ["set" | _] -> preserved_args(raw_args, 3)
      ["addcmd" | _] -> preserved_args(raw_args, 3)
      _ -> split_args(raw_args)
    end
  end

  defp parse_structured_command("perform", raw_args) do
    case split_args(raw_args) do
      ["add" | _] -> preserved_args(raw_args, 1)
      _ -> split_args(raw_args)
    end
  end

  defp parse_structured_command("timer", raw_args) do
    case split_args(raw_args) do
      [_name, "repeat" | _] -> preserved_args(raw_args, 3)
      [_name | _] -> preserved_args(raw_args, 2)
      _ -> []
    end
  end

  defp split_args(raw_args) do
    String.split(raw_args, ~r/\s+/, trim: true)
  end

  defp preserved_args(raw_args, fixed_count) do
    raw_args
    |> String.trim()
    |> split_preserving_rest(fixed_count, [])
  end

  defp split_preserving_rest("", _fixed_count, acc), do: Enum.reverse(acc)

  defp split_preserving_rest(rest, 0, acc), do: Enum.reverse([String.trim(rest) | acc])

  defp split_preserving_rest(rest, fixed_count, acc) do
    case Regex.run(~r/^(\S+)(?:\s+(.*))?$/s, rest, capture: :all_but_first) do
      [token] ->
        Enum.reverse([token | acc])

      [token, remaining] ->
        split_preserving_rest(remaining, fixed_count - 1, [token | acc])
    end
  end
end
