defmodule RetroHexChat.Commands.Handlers.MuteCmd do
  @moduledoc "Handler for /mute <nickname> [duration] — channel-level mute."
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.{Duration, Handler}

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, "Usage: /mute <nickname> [duration]"}

  def execute([nick | rest], context) do
    with {:ok, channel} <- require_channel(context),
         :ok <- require_operator(context, channel) do
      duration = Duration.parse(List.first(rest))

      {:ok, :ui_action, :channel_mute_user, %{channel: channel, target: nick, duration: duration}}
    end
  end

  @impl true
  def help do
    %{
      name: "mute",
      syntax: "/mute <nickname> [duration]",
      description:
        "Mute a user in the current channel. They cannot send messages.\nDuration: 30s, 5m, 1h, 1d. Omit for permanent.\nRequires: channel operator or owner.",
      examples: ["/mute troll", "/mute troll 30m"]
    }
  end

  @impl true
  def category, do: :channel

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "mute",
      syntax: "/mute <nickname> [duration]",
      description: "Mute a user in the current channel.",
      category: :channel,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: "User to mute"
        },
        %Parameter{
          name: "duration",
          required: false,
          type: :text,
          position: 1,
          description: "Duration (e.g. 30s, 5m, 1h)"
        }
      ],
      examples: ["/mute troll", "/mute troll 30m"]
    }
  end

  defp require_channel(%{active_channel: nil}), do: {:error, "You are not in any channel"}
  defp require_channel(%{active_channel: ch}), do: {:ok, ch}

  defp require_operator(context, channel) do
    if channel in context.operator_in do
      :ok
    else
      {:error, "You must be a channel operator to use this command"}
    end
  end
end
