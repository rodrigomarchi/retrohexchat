defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.DeleteConfirmDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.DeleteConfirmDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Delete Confirm Dialog"),
       active_page: "delete-confirm-dialog"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Delete Confirm Dialog")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Delete Message")}
        description="Destructive confirmation dialog for message deletion."
      >
        <.button variant="destructive" phx-click={show_modal("delete-msg-confirm")}>
          <:icon><Icons.icon_dialog_delete class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Delete Message")}
        </.button>
        <.delete_confirm_dialog id="delete-msg-confirm" message_id={42} />
        <.code_example>
          &lt;.delete_confirm_dialog
          id="delete-msg-confirm"
          message_id=&#123;42&#125;
          on_confirm=&#123;JS.push("delete_message")&#125;
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
