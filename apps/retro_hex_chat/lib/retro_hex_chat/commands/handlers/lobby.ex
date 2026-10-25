defmodule RetroHexChat.Commands.Handlers.Lobby do
  @moduledoc "Handler for /p2p <nickname> — open a P2P session (all features at once)."

  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Handler.Guards
  alias RetroHexChat.Nickname
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Services.Queries
  alias RetroHexChat.Topics

  use RetroHexChat.Commands.Handler,
    name: "p2p",
    category: :user,
    usage: dgettext("commands", "Usage: /p2p <nickname>"),
    syntax: dgettext("commands", "/p2p <nickname>"),
    summary:
      dgettext(
        "commands",
        "Open a P2P session that hosts calls, file transfers, and games together over one connection.\nRequires: both users must be registered and identified (/ns identify)."
      ),
    description:
      dgettext(
        "commands",
        "Open a P2P session with another user: one persistent connection that runs an audio/video call, file transfers, and games all at the same time.\nRequires: both users must be registered and identified (/ns identify)."
      ),
    examples: [dgettext("commands", "/p2p mario")],
    parameters: [
      Parameter.required(:nick, "nickname", dgettext("commands", "Target user"))
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, dgettext("commands", "Usage: /p2p <nickname>")}

  def execute([target | _rest], context) do
    with :ok <-
           Guards.require_identified(
             context,
             dgettext("commands", "You must be identified to use /p2p.")
           ),
         :ok <- validate_not_self(target, context),
         {:ok, target_id} <- resolve_registered_nick(target),
         :ok <- validate_target_online(target),
         {:ok, creator_id} <- resolve_registered_nick(context.nickname),
         :ok <- RetroHexChat.Lobby.can_ask_for_session?(creator_id, target_id) do
      {:ok, :ui_action, :lobby_invite,
       %{target: target, target_id: target_id, creator_id: creator_id}}
    end
  end

  defp validate_not_self(target, %{nickname: nick}) do
    if Nickname.equal?(target, nick) do
      {:error, dgettext("commands", "You cannot start a P2P session with yourself.")}
    else
      :ok
    end
  end

  defp validate_target_online(target) do
    if Tracker.online?(Topics.presence(), target) do
      :ok
    else
      {:error, dgettext("commands", "User '%{nickname}' is offline.", nickname: target)}
    end
  end

  defp resolve_registered_nick(nickname) do
    case Queries.find_by_nickname(nickname) do
      nil ->
        {:error,
         dgettext("commands", "User '%{nickname}' is not registered.", nickname: nickname)}

      nick ->
        {:ok, nick.id}
    end
  end
end
