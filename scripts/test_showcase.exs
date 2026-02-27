routes = [
  "/showcase",
  "/showcase/button",
  "/showcase/input",
  "/showcase/label",
  "/showcase/textarea",
  "/showcase/select",
  "/showcase/checkbox",
  "/showcase/radio-group",
  "/showcase/switch",
  "/showcase/slider",
  "/showcase/toggle",
  "/showcase/toggle-group",
  "/showcase/alert",
  "/showcase/badge",
  "/showcase/progress",
  "/showcase/skeleton",
  "/showcase/tooltip",
  "/showcase/card",
  "/showcase/separator",
  "/showcase/tabs",
  "/showcase/accordion",
  "/showcase/avatar",
  "/showcase/table",
  "/showcase/icons",
  "/showcase/diagrams",
  "/showcase/window",
  "/showcase/menu",
  "/showcase/toolbar",
  "/showcase/status-bar",
  "/showcase/irc-tabs",
  "/showcase/chat-message",
  "/showcase/chat-input",
  "/showcase/tree-view",
  "/showcase/nicklist",
  "/showcase/game-cards",
  "/showcase/fieldset",
  "/showcase/dialog",
  "/showcase/dropdown-menu",
  "/showcase/breadcrumb",
  "/showcase/pagination",
  "/showcase/toast",
  "/showcase/context-menu",
  "/showcase/loading-spinner",
  "/showcase/empty-state",
  "/showcase/color-picker",
  "/showcase/scroll-area",
  "/showcase/conversations",
  "/showcase/hover-card",
  "/showcase/search-bar",
  "/showcase/topic-bar",
  "/showcase/formatting-toolbar",
  "/showcase/emoji-picker",
  "/showcase/autocomplete",
  "/showcase/tab-bar",
  "/showcase/reply-bar",
  "/showcase/connection-status",
  "/showcase/confirm-dialog",
  "/showcase/options-dialog",
  "/showcase/channel-dialog",
  "/showcase/address-book",
  "/showcase/about-dialog",
  "/showcase/channel-list",
  "/showcase/highlight-dialog",
  "/showcase/config-form",
  "/showcase/p2p-lobby",
  "/showcase/media-controls",
  "/showcase/file-transfer",
  "/showcase/bot-manager",
  "/showcase/admin-console",
  "/showcase/chat-layout"
]

conn_base = Phoenix.ConnTest.build_conn()

results =
  Enum.map(routes, fn route ->
    try do
      conn = Phoenix.ConnTest.get(conn_base, route)

      if conn.status == 200 do
        {:ok, route}
      else
        {:error, route, "HTTP #{conn.status}"}
      end
    rescue
      e -> {:error, route, Exception.message(e) |> String.slice(0..200)}
    end
  end)

errors = Enum.filter(results, &(elem(&1, 0) == :error))
oks = Enum.filter(results, &(elem(&1, 0) == :ok))

IO.puts("OK: #{length(oks)}/#{length(routes)}")
IO.puts("")

if errors != [] do
  IO.puts("ERRORS:")

  Enum.each(errors, fn {:error, route, msg} ->
    IO.puts("  #{route}")
    IO.puts("    #{msg}")
    IO.puts("")
  end)
end
