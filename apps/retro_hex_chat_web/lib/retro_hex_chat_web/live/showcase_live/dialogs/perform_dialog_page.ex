defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.PerformDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.PerformDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Perform Dialog"),
       active_page: :perform_dialog,
       perform_selected: nil,
       autojoin_selected: nil,
       active_tab: "commands",
       perform_enabled: true,
       sample_commands: sample_commands(),
       sample_autojoin: sample_autojoin()
     )}
  end

  @impl true
  def handle_event("select-perform", %{"position" => pos}, socket) do
    {:noreply, assign(socket, perform_selected: String.to_integer(pos))}
  end

  def handle_event("select-autojoin", %{"channel" => channel}, socket) do
    {:noreply, assign(socket, autojoin_selected: channel)}
  end

  def handle_event("toggle-perform-enabled", _params, socket) do
    {:noreply, assign(socket, perform_enabled: !socket.assigns.perform_enabled)}
  end

  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  # ── Sample Data ───────────────────────────────────────

  defp sample_commands do
    [
      %{position: 1, command: "/msg NickServ IDENTIFY mySecretPassword"},
      %{position: 2, command: "/join #lobby"},
      %{position: 3, command: "/mode +x"},
      %{position: 4, command: "/join #dev"},
      %{position: 5, command: "/ns identify anotherPass"}
    ]
  end

  defp sample_autojoin do
    [
      %{channel_name: "#lobby", channel_key: nil},
      %{channel_name: "#secret", channel_key: "key123"},
      %{channel_name: "#dev", channel_key: nil},
      %{channel_name: "#vip", channel_key: "s3cret"}
    ]
  end
end
