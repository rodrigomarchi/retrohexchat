defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.NickChangeDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.NickChangeDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers

  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, page_title: gettext("Nick Change Dialog"), active_page: "nick-change-dialog")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Nick Change Dialog")}</h2>

      <.showcase_card
        title={gettext("Unregistered Nick")}
        description="Simple confirmation — no password required for unregistered nicknames."
      >
        <.button variant="outline" phx-click={show_modal("nick-change-unreg")}>
          <:icon><Icons.icon_dialog_nick class="w-4 h-4" /></:icon>
          {gettext("Change to Unregistered Nick")}
        </.button>
        <.nick_change_dialog
          id="nick-change-unreg"
          target_nick="newuser42"
          registered={false}
        />
        <.code_example>
          &lt;.nick_change_dialog
          id="nick-change"
          target_nick="newuser42"
          registered={false} on_confirm="confirm_nick_change"
          on_cancel="cancel_nick_change"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("Registered Nick")}
        description="Password field shown when the target nick is registered with NickServ."
      >
        <.button variant="outline" phx-click={show_modal("nick-change-reg")}>
          <:icon><Icons.icon_dialog_nick class="w-4 h-4" /></:icon>
          {gettext("Change to Registered Nick")}
        </.button>
        <.nick_change_dialog
          id="nick-change-reg"
          target_nick="alice"
          registered={true}
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Password Error State")}
        description="Error message shown when the NickServ password is incorrect."
      >
        <.button variant="outline" phx-click={show_modal("nick-change-error")}>
          <:icon><Icons.icon_dialog_nick class="w-4 h-4" /></:icon>
          {gettext("Change Nick (with Error)")}
        </.button>
        <.nick_change_dialog
          id="nick-change-error"
          target_nick="alice"
          registered={true}
          password_error="Incorrect password for alice. Please try again."
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
