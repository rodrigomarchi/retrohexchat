defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.ChannelCentralDialogPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ChannelCentralDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def handle_event("select_entry", %{"mask" => mask}, socket) do
    {:noreply, assign(socket, ban_selected: mask)}
  end

  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Channel Central Dialog",
       active_page: :channel_central_dialog,
       ban_selected: nil,
       ban_ex_selected: nil,
       invite_ex_selected: nil,
       sample_bans: sample_bans(),
       sample_ban_exceptions: sample_ban_exceptions(),
       sample_invite_exceptions: sample_invite_exceptions(),
       sample_modes: sample_modes()
     )}
  end

  # ── Sample Data ───────────────────────────────────────

  defp sample_modes do
    %{moderated: false, invite_only: true, topic_lock: false, key: "secret", limit: 50}
  end

  defp sample_bans do
    [
      %{mask: "*!*@troll.host", set_by: "Admin", set_at: "2025-12-01"},
      %{mask: "spammer!*@*", set_by: "Troll", set_at: "2025-12-10"},
      %{mask: "*!*@*.bad.isp", set_by: "Admin", set_at: "2025-12-14"}
    ]
  end

  defp sample_ban_exceptions do
    [
      %{mask: "friend!*@troll.host", set_by: "Admin", set_at: "2025-12-02"}
    ]
  end

  defp sample_invite_exceptions do
    [
      %{mask: "vip!*@*.good.isp", set_by: "Troll", set_at: "2025-12-05"}
    ]
  end
end
