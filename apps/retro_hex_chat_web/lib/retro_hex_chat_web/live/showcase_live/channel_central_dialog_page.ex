defmodule RetroHexChatWeb.ShowcaseLive.ChannelCentralDialogPage do
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
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Channel Central Dialog",
       active_page: :channel_central_dialog,
       ban_selected: nil,
       ban_ex_selected: nil,
       invite_ex_selected: nil
     )}
  end

  @impl true
  def handle_event("select_entry", %{"mask" => mask}, socket) do
    {:noreply, assign(socket, ban_selected: mask)}
  end

  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        sample_bans: sample_bans(),
        sample_ban_exceptions: sample_ban_exceptions(),
        sample_invite_exceptions: sample_invite_exceptions(),
        sample_modes: sample_modes()
      )

    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Channel Central Dialog</h2>

      <.showcase_card
        title="Operator View"
        description="Channel Central with full operator access — all fields are editable."
      >
        <.button phx-click={show_modal("channel-central-op")}>
          <:icon><Icons.icon_btn_channel_central /></:icon>
          Open as Operator
        </.button>

        <.channel_central_dialog
          id="channel-central-op"
          show={false}
          channel_name="#retro-chat"
          topic="Welcome to RetroHexChat! Type /help for commands."
          topic_set_by="Troll"
          topic_set_at="2025-12-15 14:30"
          created_at="2025-01-01 00:00"
          member_count={42}
          operator={true}
          modes={@sample_modes}
          bans={@sample_bans}
          ban_exceptions={@sample_ban_exceptions}
          invite_exceptions={@sample_invite_exceptions}
          ban_selected={@ban_selected}
          ban_ex_selected={@ban_ex_selected}
          invite_ex_selected={@invite_ex_selected}
        />

        <.code_example>
          &lt;.channel_central_dialog
          id="channel-central"
          show=&#123;true&#125;
          channel_name="#retro-chat"
          topic="Welcome!"
          topic_set_by="Troll"
          operator=&#123;true&#125;
          modes=&#123;%&#123;moderated: false, invite_only: true&#125;&#125;
          bans=&#123;@bans&#125;
          on_topic_save="save-topic"
          on_mode_apply="apply-modes"
          on_ban_add="add-ban"
          on_ban_remove="remove-ban"
          on_close="close"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Regular User View"
        description="Channel Central as a non-operator — topic and modes are read-only, list management is hidden."
      >
        <.button phx-click={show_modal("channel-central-user")}>
          <:icon><Icons.icon_btn_channel_central /></:icon>
          Open as User
        </.button>

        <.channel_central_dialog
          id="channel-central-user"
          show={false}
          channel_name="#lobby"
          topic="General discussion channel"
          topic_set_by="Admin"
          topic_set_at="2025-11-20 09:15"
          created_at="2025-01-01 00:00"
          member_count={128}
          operator={false}
          modes={%{moderated: true, invite_only: false, topic_lock: true, key: nil, limit: 200}}
          bans={@sample_bans}
          ban_exceptions={[]}
          invite_exceptions={[]}
        />
      </.showcase_card>

      <.showcase_card
        title="Tabs Overview"
        description="The dialog has 5 tabs for comprehensive channel management."
      >
        <div class="overflow-x-auto">
          <table class="w-full text-xs">
            <thead>
              <tr class="border-b">
                <th class="text-left px-2 py-1">Tab</th>
                <th class="text-left px-2 py-1">Contents</th>
                <th class="text-left px-2 py-1">Operator Only</th>
              </tr>
            </thead>
            <tbody>
              <tr class="border-b">
                <td class="px-2 py-1 font-bold">General</td>
                <td class="px-2 py-1">Channel info, topic editing</td>
                <td class="px-2 py-1">Topic save button</td>
              </tr>
              <tr class="border-b">
                <td class="px-2 py-1 font-bold">Modes</td>
                <td class="px-2 py-1">Moderated, invite-only, topic lock, key, limit</td>
                <td class="px-2 py-1">Apply modes button, field editing</td>
              </tr>
              <tr class="border-b">
                <td class="px-2 py-1 font-bold">Bans</td>
                <td class="px-2 py-1">Ban masks with set_by/set_at</td>
                <td class="px-2 py-1">Add/Remove buttons</td>
              </tr>
              <tr class="border-b">
                <td class="px-2 py-1 font-bold">Ban Exc.</td>
                <td class="px-2 py-1">Ban exception masks</td>
                <td class="px-2 py-1">Add/Remove buttons</td>
              </tr>
              <tr>
                <td class="px-2 py-1 font-bold">Invite Exc.</td>
                <td class="px-2 py-1">Invite exception masks</td>
                <td class="px-2 py-1">Add/Remove buttons</td>
              </tr>
            </tbody>
          </table>
        </div>
      </.showcase_card>
    </.showcase_layout>
    """
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
