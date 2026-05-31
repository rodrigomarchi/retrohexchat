defmodule RetroHexChat.Commands.Handlers.Ignore do
  @moduledoc "Handler for /ignore [nickname] [type] [duration]"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Chat.IgnoreEntry
  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: :ok
  def validate(_args), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:ok, :ui_action, :ignore_list, %{}}
  end

  def execute([nick | rest], %{nickname: own_nick}) do
    if String.downcase(nick) == String.downcase(own_nick) do
      {:error, gettext("You cannot ignore yourself")}
    else
      parse_type_and_duration(nick, rest)
    end
  end

  @impl true
  @spec help() :: %{
          name: String.t(),
          syntax: String.t(),
          description: String.t(),
          examples: [String.t()]
        }
  def help do
    %{
      name: "ignore",
      syntax: gettext("/ignore [nickname] [type] [duration]"),
      description:
        gettext(
          "Hide messages from a specific user.\nTypes: all (default), messages, pms, actions, notices, invites.\nDuration: Nm (minutes), Nh (hours), Nd (days). No duration = permanent until /unignore.\nNo args: show your ignore list. You cannot ignore yourself."
        ),
      examples: [
        gettext("/ignore SpamBot"),
        gettext("/ignore AnnoyingGuy pms"),
        gettext("/ignore LoudPerson all 5m"),
        "/ignore"
      ]
    }
  end

  defp parse_type_and_duration(nick, []) do
    {:ok, :ui_action, :ignore_add, %{nickname: nick, type: :all, duration: nil}}
  end

  defp parse_type_and_duration(nick, [type_str | rest]) do
    type = String.to_atom(type_str)

    if IgnoreEntry.valid_type?(type) do
      build_ignore_result(nick, type, rest)
    else
      valid = IgnoreEntry.valid_types() |> Enum.map_join(", ", &Atom.to_string/1)
      {:error, "Invalid ignore type: #{type_str}. Valid types: #{valid}"}
    end
  end

  defp build_ignore_result(nick, type, []) do
    {:ok, :ui_action, :ignore_add, %{nickname: nick, type: type, duration: nil}}
  end

  defp build_ignore_result(nick, type, [duration_str]) do
    case parse_duration(duration_str) do
      {:ok, seconds} ->
        {:ok, :ui_action, :ignore_add, %{nickname: nick, type: type, duration: seconds}}

      {:error, msg} ->
        {:error, msg}
    end
  end

  defp build_ignore_result(_nick, _type, _) do
    {:error, gettext("Usage: /ignore <nickname> [type] [duration]")}
  end

  @spec parse_duration(String.t()) :: {:ok, pos_integer()} | {:error, String.t()}
  defp parse_duration(str) do
    case Regex.run(~r/^(\d+)([mhd])$/, str) do
      [_, num_str, unit] ->
        num = String.to_integer(num_str)

        if num <= 0 do
          {:error, gettext("Duration must be positive")}
        else
          seconds = num * unit_multiplier(unit)
          {:ok, seconds}
        end

      _ ->
        {:error, "Invalid duration format: #{str}. Use Nm (minutes), Nh (hours), or Nd (days)"}
    end
  end

  defp unit_multiplier("m"), do: 60
  defp unit_multiplier("h"), do: 3600
  defp unit_multiplier("d"), do: 86_400

  @impl true
  def category, do: :user

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "ignore",
      syntax: gettext("/ignore [nickname] [type] [duration]"),
      description:
        gettext(
          "Hide messages from a specific user.\nTypes: all (default), messages, pms, actions, notices, invites.\nDuration: Nm (minutes), Nh (hours), Nd (days). No duration = permanent until /unignore.\nNo args: show your ignore list. You cannot ignore yourself."
        ),
      category: :user,
      parameters: [
        %Parameter{
          name: "nickname",
          required: false,
          type: :nick,
          position: 0,
          description: gettext("User to ignore")
        },
        %Parameter{
          name: "type",
          required: false,
          type: :text,
          position: 1,
          description: gettext("Type: all, messages, pms, actions, notices, invites")
        },
        %Parameter{
          name: "duration",
          required: false,
          type: :text,
          position: 2,
          description: gettext("Duration: 5m, 1h, 2d")
        }
      ],
      examples: [
        gettext("/ignore SpamBot"),
        gettext("/ignore AnnoyingGuy pms"),
        gettext("/ignore LoudPerson all 5m"),
        "/ignore"
      ]
    }
  end
end
