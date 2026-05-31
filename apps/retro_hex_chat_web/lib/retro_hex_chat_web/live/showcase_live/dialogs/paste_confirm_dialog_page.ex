defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.PasteConfirmDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.PasteConfirmDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers

  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Paste Confirm Dialog"),
       active_page: "paste-confirm-dialog"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Paste Confirm Dialog")}</h2>

      <.showcase_card
        title={gettext("Standard Paste Confirmation")}
        description="Warns the user before sending multiple lines of text."
      >
        <.button variant="outline" phx-click={show_modal("paste-standard")}>
          <:icon><Icons.icon_dialog_paste class="w-4 h-4" /></:icon>
          {gettext("Paste 5 Lines")}
        </.button>
        <.paste_confirm_dialog
          id="paste-standard"
          show={false}
          line_count={5}
          on_send="send_paste"
          on_cancel="cancel_paste"
        />
        <.code_example>
          &lt;.paste_confirm_dialog
          id="paste-standard"
          line_count={5} on_send="send_paste"
          on_cancel="cancel_paste"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("Flood Warning")}
        description="Shows a flood protection warning when line count exceeds limits."
      >
        <.button variant="outline" phx-click={show_modal("paste-flood")}>
          <:icon><Icons.icon_dialog_paste class="w-4 h-4" /></:icon>
          {gettext("Paste 25 Lines (Flood Warning)")}
        </.button>
        <.paste_confirm_dialog
          id="paste-flood"
          show={false}
          line_count={25}
          flood_warning={true}
          on_send="send_paste"
          on_cancel="cancel_paste"
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Send Disabled")}
        description="Send All button is disabled when flood protection blocks sending."
      >
        <.button variant="outline" phx-click={show_modal("paste-disabled")}>
          <:icon><Icons.icon_dialog_paste class="w-4 h-4" /></:icon>
          {gettext("Paste Blocked")}
        </.button>
        <.paste_confirm_dialog
          id="paste-disabled"
          show={false}
          line_count={50}
          flood_warning={true}
          send_disabled={true}
          on_cancel="cancel_paste"
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Single Line")}
        description="Singular phrasing when only one line is being pasted."
      >
        <.button variant="outline" phx-click={show_modal("paste-single")}>
          <:icon><Icons.icon_dialog_paste class="w-4 h-4" /></:icon>
          {gettext("Paste 1 Line")}
        </.button>
        <.paste_confirm_dialog
          id="paste-single"
          show={false}
          line_count={1}
          on_send="send_paste"
          on_cancel="cancel_paste"
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
