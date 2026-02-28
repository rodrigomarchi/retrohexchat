defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.SoundSettingsDialogPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.SoundSettingsDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Sound Settings Dialog",
       active_page: "sound-settings-dialog",
       sound_settings: %{
         message: %{sound: "Default", flash: false},
         pm: %{sound: "Beep", flash: true},
         highlight: %{sound: "Chime", flash: true},
         join: %{sound: "Default", flash: false},
         part: %{sound: "Default", flash: false},
         kick: %{sound: "Ding", flash: true},
         connect: %{sound: "Chime", flash: false},
         disconnect: %{sound: "Beep", flash: true},
         buddy_online: %{sound: "Ding", flash: false},
         buddy_offline: %{sound: "Default", flash: false}
       }
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Sound Settings Dialog</h2>

      <.showcase_card
        title="Full Settings"
        description="Sound event settings with per-event sound selection, flash toggle, and preview button. All 10 IRC events are shown."
      >
        <.button variant="outline" phx-click={show_modal("sound-settings-demo")}>
          <:icon><Icons.icon_dialog_sound class="w-4 h-4" /></:icon>
          Open Sound Settings
        </.button>
        <.sound_settings_dialog id="sound-settings-demo" settings={@sound_settings} />
        <.code_example>
          &lt;.sound_settings_dialog
          id="sound-settings"
          settings=&#123;@sound_settings&#125;
          on_ok="ss-ok"
          on_cancel="ss-cancel"
          on_apply="ss-apply"
          on_sound_change="ss-sound-change"
          on_flash_toggle="ss-flash-toggle"
          on_preview="ss-preview"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Custom Sound Options"
        description="Sound settings with a custom list of available sounds."
      >
        <.button variant="outline" phx-click={show_modal("sound-settings-custom")}>
          <:icon><Icons.icon_dialog_sound class="w-4 h-4" /></:icon>
          Open Sound Settings (Custom Sounds)
        </.button>
        <.sound_settings_dialog
          id="sound-settings-custom"
          settings={@sound_settings}
          available_sounds={["None", "Default", "Beep", "Chime", "Ding", "Alert", "Ping"]}
        />
      </.showcase_card>

      <.showcase_card
        title="Empty Settings"
        description="Sound settings with no prior configuration — all events default to 'Default' sound, flash off."
      >
        <.button variant="outline" phx-click={show_modal("sound-settings-empty")}>
          <:icon><Icons.icon_dialog_sound class="w-4 h-4" /></:icon>
          Open Sound Settings (Defaults)
        </.button>
        <.sound_settings_dialog id="sound-settings-empty" settings={%{}} />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
