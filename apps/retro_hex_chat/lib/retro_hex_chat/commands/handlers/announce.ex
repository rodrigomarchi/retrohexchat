defmodule RetroHexChat.Commands.Handlers.Announce do
  @moduledoc "Handler for /announce <message> — admin global broadcast."
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @pubsub RetroHexChat.PubSub
  @topic "server:announcements"

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, %{is_admin: false}) do
    {:error, dgettext("commands", "Permission denied: you must be a server administrator.")}
  end

  def execute([], _context) do
    {:error, dgettext("commands", "Usage: /announce <message>")}
  end

  def execute(args, %{is_admin: true, nickname: sender}) do
    content = Enum.join(args, " ")

    Phoenix.PubSub.broadcast(
      @pubsub,
      @topic,
      {:announcement,
       %{
         sender: sender,
         content: content,
         timestamp: DateTime.utc_now()
       }}
    )

    {:ok, :system, %{content: dgettext("commands", "Announcement sent to all users.")}}
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
      name: "announce",
      syntax: dgettext("commands", "/announce <message>"),
      description:
        dgettext(
          "commands",
          "Send an urgent broadcast message to every connected user. Bypasses all ignore filters.\nRequires: server administrator."
        ),
      examples: [dgettext("commands", "/announce Server will restart at midnight")]
    }
  end

  @impl true
  def category, do: :advanced

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "announce",
      syntax: dgettext("commands", "/announce <message>"),
      description:
        dgettext(
          "commands",
          "Send an urgent broadcast message to every connected user. Bypasses all ignore filters."
        ),
      category: :advanced,
      parameters: [
        %Parameter{
          name: "message",
          required: true,
          type: :text,
          position: 0,
          description: dgettext("commands", "Global announcement message")
        }
      ],
      examples: [dgettext("commands", "/announce Server will restart at midnight")]
    }
  end
end
