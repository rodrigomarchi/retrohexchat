defmodule RetroHexChatWeb.ShowcaseLive.InviteDialogPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.InviteDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers

  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Invite Dialog", active_page: "invite-dialog")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Invite Dialog</h2>

      <.showcase_card
        title="Single Invite"
        description="A single channel invite from another user."
      >
        <.button variant="outline" phx-click={show_modal("invite-single")}>
          <:icon><Icons.icon_dialog_invite class="w-4 h-4" /></:icon>
          Show Single Invite
        </.button>
        <.invite_dialog
          id="invite-single"
          show={false}
          invites={[%{channel: "#lobby", from: "alice"}]}
          on_accept="accept_invite"
          on_ignore="ignore_invite"
        />
        <.code_example>
          &lt;.invite_dialog
          id="invite-single"
          invites=&#123;[%&#123;channel: "#lobby", from: "alice"&#125;]&#125;
          on_accept="accept_invite"
          on_ignore="ignore_invite"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Multiple Invites (Stacked)"
        description="Multiple pending invites rendered as stacked dialog cards."
      >
        <.button variant="outline" phx-click={show_modal("invite-multi")}>
          <:icon><Icons.icon_dialog_invite class="w-4 h-4" /></:icon>
          Show Stacked Invites
        </.button>
        <.invite_dialog
          id="invite-multi"
          show={false}
          invites={[
            %{channel: "#lobby", from: "alice"},
            %{channel: "#dev", from: "bob"},
            %{channel: "#offtopic", from: "carol"}
          ]}
          on_accept="accept_invite"
          on_ignore="ignore_invite"
        />
      </.showcase_card>

      <.showcase_card
        title="No Pending Invites"
        description="Empty invite list — shows placeholder message."
      >
        <.button variant="outline" phx-click={show_modal("invite-empty")}>
          <:icon><Icons.icon_dialog_invite class="w-4 h-4" /></:icon>
          Show Empty Invite Dialog
        </.button>
        <.invite_dialog
          id="invite-empty"
          show={false}
          invites={[]}
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
