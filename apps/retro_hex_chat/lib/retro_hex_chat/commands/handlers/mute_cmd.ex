defmodule RetroHexChat.Commands.Handlers.MuteCmd do
  @moduledoc "Handler for /mute <nickname> [duration] — channel-level mute."
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.{Duration, Handler}

  use RetroHexChat.Commands.Handler,
    name: "mute",
    category: :channel,
    syntax: dgettext("commands", "/mute <nickname> [duration]"),
    summary: dgettext("commands", "Mute a user in the current channel."),
    description:
      dgettext(
        "commands",
        "Mute a user in the current channel. They cannot send messages.\nDuration: 30s, 5m, 1h, 1d. Omit for permanent.\nRequires: channel operator or owner."
      ),
    examples: [dgettext("commands", "/mute troll"), dgettext("commands", "/mute troll 30m")],
    parameters: [
      Parameter.required(:nick, "nickname", dgettext("commands", "User to mute")),
      Parameter.optional(:text, "duration", dgettext("commands", "Duration (e.g. 30s, 5m, 1h)"))
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context),
    do: {:error, dgettext("commands", "Usage: /mute <nickname> [duration]")}

  def execute([nick | rest], context) do
    with {:ok, channel} <- require_channel(context),
         :ok <- require_operator(context, channel) do
      duration = Duration.parse(List.first(rest))

      {:ok, :ui_action, :channel_mute_user, %{channel: channel, target: nick, duration: duration}}
    end
  end
end
