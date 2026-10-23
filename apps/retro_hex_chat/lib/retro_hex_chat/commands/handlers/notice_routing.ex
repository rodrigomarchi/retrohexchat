defmodule RetroHexChat.Commands.Handlers.NoticeRouting do
  @moduledoc """
  Handler for the /notice_routing command.
  Notice routing is now hardcoded to active window.
  """
  use Gettext, backend: RetroHexChat.Gettext

  use RetroHexChat.Commands.Handler,
    name: "notice_routing",
    category: :user,
    syntax: "/notice_routing",
    summary: dgettext("commands", "Notices are always routed to the active window."),
    description: dgettext("commands", "Notices are always routed to the active window."),
    examples: ["/notice_routing"]

  @impl true
  @spec execute([String.t()], RetroHexChat.Commands.Handler.context()) ::
          RetroHexChat.Commands.Handler.result()
  def execute(_, _context),
    do: {:ok, :ui_action, :notice_routing_show, %{}}
end
