defmodule RetroHexChatWeb.ShowcaseLive.ConfirmDialogPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ConfirmDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Confirm Dialog", active_page: "confirm-dialog")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Confirm Dialog</h2>

      <.showcase_card
        title="Default Confirmation"
        description="Standard confirmation dialog with OK/Cancel."
      >
        <.button variant="outline" phx-click={show_modal("confirm-default")}>
          <:icon><Icons.icon_warning class="w-4 h-4" /></:icon>
          Show Confirm
        </.button>
        <.confirm_dialog
          id="confirm-default"
          title="Confirm Action"
          message="Are you sure you want to proceed with this action?"
        />
        <.code_example>
          &lt;.confirm_dialog
            id="confirm-default"
            title="Confirm Action"
            message="Are you sure?"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Destructive Confirmation"
        description="Destructive variant for dangerous actions."
      >
        <.button variant="destructive" phx-click={show_modal("confirm-delete")}>
          <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
          Delete Channel
        </.button>
        <.confirm_dialog
          id="confirm-delete"
          title="Delete Channel"
          message="Are you sure you want to delete #lobby? This action cannot be undone."
          confirm_label="Delete"
          variant="destructive"
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
