defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.AutoRespondDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.AutoRespondDialog
  import RetroHexChatWeb.ShowcaseHelpers

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
           command: "/notice $nick Hello!",
           enabled: true
         },
         %{
           position: 2,
           trigger: "on_part",
           channel: "",
           command: "/me waves goodbye",
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

  # A showcase page renders the component and nothing behind it, so the
  # controls it draws have nowhere to go. Answering them is what keeps a
  # click from taking the page down with an unmatched event.
  @impl true
  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Auto Respond Dialog")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Default State")}
        description="Auto-respond rules list. Rules can be enabled/disabled per row with the checkbox. Trigger types: On Join, On Part, On Nick Change."
      >
        <div class="relative h-[380px] shadow-retro-field overflow-hidden p-2">
          <.auto_respond_panel id="auto-respond-demo" rules={@rules} />
        </div>
        <.code_example>
          &lt;.auto_respond_panel
          id="auto-respond"
          rules=&#123;@rules&#125;
          on_toggle="ar-toggle"
          on_add="ar-add"
          on_edit="ar-edit"
          on_delete="ar-delete"
          on_save="ar-save"
          on_cancel_edit="ar-cancel"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Editing State")}
        description="Edit form panel visible on the right. The draft fields are pre-populated for editing an existing rule."
      >
        <div class="relative h-[380px] shadow-retro-field overflow-hidden p-2">
          <.auto_respond_panel
            id="auto-respond-editing"
            rules={@rules}
            editing={true}
            draft_trigger="on_join"
            draft_channel="#lobby"
            draft_command="/notice $nick Hello!"
          />
        </div>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Empty State")}
        description="Auto-respond dialog with no rules configured yet."
      >
        <div class="relative h-[380px] shadow-retro-field overflow-hidden p-2">
          <.auto_respond_panel id="auto-respond-empty" rules={[]} />
        </div>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
