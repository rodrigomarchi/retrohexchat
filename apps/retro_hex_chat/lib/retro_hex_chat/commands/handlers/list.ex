defmodule RetroHexChat.Commands.Handlers.List do
  @moduledoc "Handler for /list"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "list",
    category: :channel,
    syntax: "/list",
    summary:
      dgettext(
        "commands",
        "Browse all public channels on the server in a sortable, filterable dialog."
      ),
    description:
      dgettext(
        "commands",
        "Browse all public channels on the server in a sortable, filterable dialog."
      ),
    examples: ["/list"]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, _context) do
    {:ok, :ui_action, :open_channel_list, %{}}
  end
end
