defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.AutoRespondDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.AutoRespondDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Auto Respond Dialog"),
       active_page: "auto-respond-dialog",
       rules: [
         %{
           position: 1,
           trigger: "on_join",
           channel: "#lobby",
           command: "/say Hello!",
           enabled: true
         },
         %{
           position: 2,
           trigger: "on_part",
           channel: "",
           command: "/say Farewell!",
           enabled: true
         },
         %{
           position: 3,
           trigger: "on_nick_change",
           channel: "",
           command: "/msg $nick Noticed your nick change",
           enabled: false
         }
       ]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Auto Respond Dialog")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Default State")}
        description="Auto-respond rules list. Rules can be enabled/disabled per row with the checkbox. Trigger types: On Join, On Part, On Nick Change."
      >
        <.button variant="outline" phx-click={show_modal("auto-respond-demo")}>
          <:icon><Icons.icon_dialog_auto_respond class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Open Auto Respond")}
        </.button>
        <.auto_respond_dialog id="auto-respond-demo" rules={@rules} />
        <.code_example>
          &lt;.auto_respond_dialog
          id="auto-respond"
          rules=&#123;@rules&#125;
          on_select="ar-select"
          on_toggle="ar-toggle"
          on_add="ar-add"
          on_edit="ar-edit"
          on_delete="ar-delete"
          on_save="ar-save"
          on_cancel_edit="ar-cancel"
          on_close="ar-close"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Editing State")}
        description="Edit form panel visible on the right. The draft fields are pre-populated for editing an existing rule."
      >
        <.button variant="outline" phx-click={show_modal("auto-respond-editing")}>
          <:icon><Icons.icon_dialog_auto_respond class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Open Auto Respond (Editing)")}
        </.button>
        <.auto_respond_dialog
          id="auto-respond-editing"
          rules={@rules}
          selected_position={1}
          editing={true}
          draft_trigger="on_join"
          draft_channel="#lobby"
          draft_command="/say Hello!"
        />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Empty State")}
        description="Auto-respond dialog with no rules configured yet."
      >
        <.button variant="outline" phx-click={show_modal("auto-respond-empty")}>
          <:icon><Icons.icon_dialog_auto_respond class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Open Auto Respond (Empty)")}
        </.button>
        <.auto_respond_dialog id="auto-respond-empty" rules={[]} />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
