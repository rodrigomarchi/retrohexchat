defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.AutojoinDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.AutojoinDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Auto-Join Dialog"),
       active_page: :autojoin_dialog,
       selected: nil,
       sample_entries: sample_entries()
     )}
  end

  @impl true
  def handle_event("select-autojoin", %{"channel" => channel}, socket) do
    {:noreply, assign(socket, selected: channel)}
  end

  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  # ── Sample Data ───────────────────────────────────────

  defp sample_entries do
    [
      %{channel_name: "#lobby", channel_key: nil},
      %{channel_name: "#secret", channel_key: "key123"},
      %{channel_name: "#dev", channel_key: nil},
      %{channel_name: "#vip", channel_key: "s3cret"}
    ]
  end
end
