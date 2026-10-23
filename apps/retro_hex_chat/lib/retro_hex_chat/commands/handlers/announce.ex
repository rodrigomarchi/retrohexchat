defmodule RetroHexChat.Commands.Handlers.Announce do
  @moduledoc "Handler for /announce <message> — admin global broadcast."
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Handler.ServerWide
  alias RetroHexChat.Topics

  use RetroHexChat.Commands.Handler,
    name: "announce",
    category: :advanced,
    syntax: dgettext("commands", "/announce <message>"),
    summary:
      dgettext(
        "commands",
        "Send an urgent broadcast message to every connected user. Bypasses all ignore filters."
      ),
    description:
      dgettext(
        "commands",
        "Send an urgent broadcast message to every connected user. Bypasses all ignore filters.\nRequires: server administrator."
      ),
    examples: [dgettext("commands", "/announce Server will restart at midnight")],
    parameters: [
      %Parameter{
        name: "message",
        required: true,
        type: :text,
        position: 0,
        description: dgettext("commands", "Global announcement message")
      }
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, %{is_admin: false}) do
    {:error, dgettext("commands", "Permission denied: you must be a server administrator.")}
  end

  def execute([], _context) do
    {:error, dgettext("commands", "Usage: /announce <message>")}
  end

  def execute(args, %{is_admin: true, nickname: sender}) do
    ServerWide.broadcast(Topics.announcements(), :announcement, sender, args)

    {:ok, :system, %{content: dgettext("commands", "Announcement sent to all users.")}}
  end
end
