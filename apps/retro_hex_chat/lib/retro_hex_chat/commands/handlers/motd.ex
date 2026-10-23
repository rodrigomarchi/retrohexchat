defmodule RetroHexChat.Commands.Handlers.Motd do
  @moduledoc "Handler for /motd — view the current Message of the Day."
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Services.Motd

  use RetroHexChat.Commands.Handler,
    name: "motd",
    category: :advanced,
    syntax: "/motd",
    summary:
      dgettext(
        "commands",
        "View the server's Message of the Day, which is also shown automatically when you connect."
      ),
    description:
      dgettext(
        "commands",
        "View the server's Message of the Day, which is also shown automatically when you connect."
      ),
    examples: ["/motd"]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, _context) do
    case Motd.get() do
      nil -> {:ok, :system, %{content: dgettext("commands", "No MOTD has been set.")}}
      content -> {:ok, :ui_action, :show_motd, %{content: content}}
    end
  end
end
