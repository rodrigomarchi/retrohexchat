defmodule RetroHexChatWeb.ShowcaseLive.OptionsDialogPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.OptionsDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Options Dialog", active_page: "options-dialog")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Options Dialog</h2>

      <.showcase_card
        title="Options Dialog"
        description="Tree-view navigation with settings panels."
      >
        <.button variant="outline" phx-click={show_modal("options-demo")}>
          <:icon><Icons.icon_dialog_options class="w-4 h-4" /></:icon>
          Open Options
        </.button>
        <.options_dialog id="options-demo" active_panel="Display">
          <:panel name="Display">
            <div class="space-y-retro-4 text-xs">
              <label class="flex items-center gap-retro-4 cursor-pointer">
                <.checkbox name="timestamps" value={true} /> Show timestamps
              </label>
              <label class="flex items-center gap-retro-4 cursor-pointer">
                <.checkbox name="joins" value={true} /> Show join/part messages
              </label>
              <label class="flex items-center gap-retro-4 cursor-pointer">
                <.checkbox name="colors" value={true} /> Enable mIRC colors
              </label>
            </div>
          </:panel>
          <:panel name="Sounds">
            <div class="space-y-retro-4 text-xs">
              <label class="flex items-center gap-retro-4 cursor-pointer">
                <.checkbox name="sound_msg" value={true} /> Message received
              </label>
              <label class="flex items-center gap-retro-4 cursor-pointer">
                <.checkbox name="sound_highlight" value={true} /> Highlight
              </label>
            </div>
          </:panel>
          <:panel name="Notifications">
            <p class="text-xs text-muted-foreground">Desktop notification settings.</p>
          </:panel>
        </.options_dialog>
        <.code_example>
          &lt;.options_dialog id="options" active_panel="Display"&gt;
          &lt;:panel name="Display"&gt;
          &lt;!-- Display settings --&gt;
          &lt;/:panel&gt;
          &lt;:panel name="Sounds"&gt;
          &lt;!-- Sound settings --&gt;
          &lt;/:panel&gt;
          &lt;/.options_dialog&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
