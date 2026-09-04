defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.AdminUsersDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.AdminUsersDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Admin Users Dialog"),
       active_page: "admin-users-dialog",
       show_users: false
     )}
  end

  @impl true
  def handle_event("toggle_users", _params, socket) do
    {:noreply, assign(socket, show_users: !socket.assigns.show_users)}
  end

  # A showcase page renders the component and nothing behind it, so the
  # controls it draws have nowhere to go. Answering them is what keeps a
  # click from taking the page down with an unmatched event.
  @impl true
  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Admin Users Dialog")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Admin Users")}
        description="Server-wide user administration: moderation, accounts and NickServ."
      >
        <.button variant="outline" phx-click="toggle_users">
          <:icon><Icons.icon_community class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Open Admin Users")}
        </.button>
        <.admin_users_dialog
          id="admin-users-demo"
          show={@show_users}
          text={dgettext("showcase", "*** User List (2 results) ***\n  Ada [registered]\n  Grace")}
          banlist_text={dgettext("showcase", "*** No active server bans.")}
          search="a"
          info_nick="Ada"
          can_refresh={true}
          can_set_admin_role={false}
          on_cancel="toggle_users"
        />
        <.code_example>
          &lt;.admin_users_dialog
          id="admin-users"
          show=&#123;@show_users&#125;
          text=&#123;@users_text&#125;
          banlist_text=&#123;@banlist_text&#125;
          can_refresh=&#123;true&#125;
          on_cancel="close_admin_users"
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
