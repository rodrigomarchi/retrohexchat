defmodule RetroHexChat.Commands.Handlers.SetMotd do
  @moduledoc "Handler for /setmotd <text> — admin sets the MOTD."
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Services.Motd

  use RetroHexChat.Commands.Handler,
    name: "setmotd",
    category: :advanced,
    syntax: dgettext("commands", "/setmotd <text>"),
    summary:
      dgettext(
        "commands",
        "Set the server's Message of the Day shown to all users when they connect."
      ),
    description:
      dgettext(
        "commands",
        "Set the server's Message of the Day shown to all users when they connect.\nRequires: server administrator. Message text is required."
      ),
    examples: [dgettext("commands", "/setmotd Welcome to RetroHexChat!")],
    parameters: [
      %Parameter{
        name: "text",
        required: true,
        type: :text,
        position: 0,
        description: dgettext("commands", "Message of the Day text")
      }
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, %{is_admin: false}) do
    {:error, dgettext("commands", "Permission denied: you must be a server administrator.")}
  end

  def execute([], _context) do
    {:error, dgettext("commands", "Usage: /setmotd <text>")}
  end

  def execute(args, %{is_admin: true, nickname: nickname}) do
    content = Enum.join(args, " ")

    case Motd.set(content, nickname) do
      :ok -> {:ok, :system, %{content: dgettext("commands", "MOTD has been updated.")}}
      {:error, msg} -> {:error, msg}
    end
  end
end
