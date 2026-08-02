defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.ChannelCentralDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ChannelCentralDialog
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def handle_event("cc_list_type", %{"list" => list_type}, socket) do
    {:noreply, assign(socket, list_type: list_type, list_selected: nil)}
  end

  def handle_event("cc_list_select", %{"nickname" => mask}, socket) do
    {:noreply, assign(socket, list_selected: mask)}
  end

  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Channel Central Dialog"),
       active_page: "channel-central-dialog",
       list_type: "bans",
       list_selected: nil,
       sample_lists: %{
         "bans" => sample_bans(),
         "ban_exceptions" => sample_ban_exceptions(),
         "invite_exceptions" => sample_invite_exceptions()
       },
       sample_modes: sample_modes()
     )}
  end

  # ── Sample Data ───────────────────────────────────────

  defp sample_modes do
    %{moderated: false, invite_only: true, topic_lock: false, key: "secret", limit: 50}
  end

  defp sample_bans do
    [
      %{
        mask: dgettext("showcase", "*!*@troll.host"),
        set_by: dgettext("showcase", "Admin"),
        set_at: "2025-12-01"
      },
      %{
        mask: dgettext("showcase", "spammer!*@*"),
        set_by: dgettext("showcase", "Troll"),
        set_at: "2025-12-10"
      },
      %{
        mask: dgettext("showcase", "*!*@*.bad.isp"),
        set_by: dgettext("showcase", "Admin"),
        set_at: "2025-12-14"
      }
    ]
  end

  defp sample_ban_exceptions do
    [
      %{
        mask: dgettext("showcase", "friend!*@troll.host"),
        set_by: dgettext("showcase", "Admin"),
        set_at: "2025-12-02"
      }
    ]
  end

  defp sample_invite_exceptions do
    [
      %{
        mask: dgettext("showcase", "vip!*@*.good.isp"),
        set_by: dgettext("showcase", "Troll"),
        set_at: "2025-12-05"
      }
    ]
  end
end
