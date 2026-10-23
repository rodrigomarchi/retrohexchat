defmodule RetroHexChat.Commands.Handlers.Wallops do
  @moduledoc "Handler for /wallops <message> — broadcast to +w users."
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Topics

  use RetroHexChat.Commands.Handler,
    name: "wallops",
    category: :user,
    syntax: dgettext("commands", "/wallops <message>"),
    summary:
      dgettext(
        "commands",
        "Send a message to all users who opted in to operator announcements via /umode +w."
      ),
    description:
      dgettext(
        "commands",
        "Send a message to all users who opted in to operator announcements via /umode +w.\nRequires: server operator or server administrator. Message text is required."
      ),
    examples: [dgettext("commands", "/wallops Server maintenance in 10 minutes")],
    parameters: [
      %Parameter{
        name: "message",
        required: true,
        type: :text,
        position: 0,
        description: dgettext("commands", "Message for all users with +w mode")
      }
    ]

  @pubsub RetroHexChat.PubSub

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, %{is_admin: false, is_server_operator: false}) do
    {:error, dgettext("commands", "Permission denied: you must be a server operator.")}
  end

  def execute([], _context) do
    {:error, dgettext("commands", "Usage: /wallops <message>")}
  end

  def execute(args, context) do
    content = Enum.join(args, " ")

    Phoenix.PubSub.broadcast(
      @pubsub,
      Topics.wallops(),
      {:wallops,
       %{
         sender: context.nickname,
         content: content,
         timestamp: DateTime.utc_now()
       }}
    )

    {:ok, :system, %{content: dgettext("commands", "Wallops sent.")}}
  end
end
