defmodule RetroHexChat.Commands.Handlers.List do
  @moduledoc "Handler for /list"
  use Gettext, backend: RetroHexChat.Gettext

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
    examples: ["/list"],
    execute: {:ui_action, :open_channel_list}
end
