defmodule RetroHexChatWeb.Components.UI.SoundSettingsDialog do
  @moduledoc """
  Sound event settings dialog component for the showcase design system.

  Composed from dialog + table + button + checkbox primitives.
  Displays a table of IRC events with per-row sound selection, flash toggle,
  and preview (play) button. OK/Cancel/Apply footer actions.

  ## Usage

      <.sound_settings_dialog
        id="sound-settings"
        show={true}
        settings={@sound_settings}
        on_ok="ss-ok"
        on_cancel="ss-cancel"
        on_apply="ss-apply"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.Select

  alias RetroHexChatWeb.Icons

  @event_labels %{
    message: "Message",
    pm: "Private Message",
    highlight: "Highlight",
    join: "User Join",
    part: "User Part",
    kick: "Kicked",
    connect: "Connected",
    disconnect: "Disconnected",
    buddy_online: "Buddy Online",
    buddy_offline: "Buddy Offline"
  }

  @doc "Renders the sound settings dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :settings, :map,
    default: %{},
    doc: "Map of event atom to %{sound, flash} e.g. %{message: %{sound: \"Beep\", flash: false}}"

  attr :available_sounds, :list,
    default: ["Default", "Beep", "Chime", "Ding"],
    doc: "Sound options for the dropdown"

  attr :on_ok, :any, default: nil, doc: "OK button callback"
  attr :on_cancel, :any, default: nil, doc: "Cancel button callback"
  attr :on_apply, :any, default: nil, doc: "Apply button callback"

  attr :on_sound_change, :any,
    default: nil,
    doc: "Sound dropdown change callback (phx-value-event)"

  attr :on_flash_toggle, :any, default: nil, doc: "Flash checkbox callback (phx-value-event)"
  attr :on_preview, :any, default: nil, doc: "Preview (play) button callback (phx-value-event)"

  @spec sound_settings_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def sound_settings_dialog(assigns) do
    assigns =
      assign(assigns, :event_order, [
        :message,
        :pm,
        :highlight,
        :join,
        :part,
        :kick,
        :connect,
        :disconnect,
        :buddy_online,
        :buddy_offline
      ])

    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header id={@id} title="Sound Settings">
        <:icon><Icons.icon_dialog_sound class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body>
        <div class="max-h-[300px] overflow-y-auto retro-scrollbar">
          <.table>
            <.table_header>
              <.table_row>
                <.table_head>Event</.table_head>
                <.table_head>Sound</.table_head>
                <.table_head class="w-[60px] text-center">Flash</.table_head>
                <.table_head class="w-[80px] text-center">Preview</.table_head>
              </.table_row>
            </.table_header>
            <.table_body>
              <.table_row :for={event <- @event_order}>
                <.table_cell class="font-bold text-xs">
                  {event_label(event)}
                </.table_cell>

                <.table_cell>
                  <form phx-change={@on_sound_change}>
                    <input type="hidden" name="event" value={event} />
                    <.select
                      :let={builder}
                      id={"sound-select-#{event}"}
                      name={"sound_#{event}"}
                      value={event_sound(@settings, event)}
                      label={event_sound(@settings, event)}
                      class="w-full"
                    >
                      <.select_trigger builder={builder} class="h-8 text-xs" />
                      <.select_content builder={builder}>
                        <.select_group>
                          <.select_item
                            :for={sound <- @available_sounds}
                            builder={builder}
                            value={sound}
                            label={sound}
                          >
                            {sound}
                          </.select_item>
                        </.select_group>
                      </.select_content>
                    </.select>
                  </form>
                </.table_cell>

                <.table_cell class="text-center">
                  <.checkbox
                    value={event_flash(@settings, event)}
                    phx-click={@on_flash_toggle}
                    phx-value-event={event}
                  />
                </.table_cell>

                <.table_cell class="text-center">
                  <.button
                    size="sm"
                    variant="outline"
                    phx-click={@on_preview}
                    phx-value-event={event}
                  >
                    <:icon><Icons.icon_btn_sounds class="w-4 h-4" /></:icon>
                    Play
                  </.button>
                </.table_cell>
              </.table_row>
            </.table_body>
          </.table>
        </div>
      </.dialog_body>

      <.dialog_footer>
        <.button variant="default" phx-click={@on_ok || hide_modal(@id)}>
          <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
          OK
        </.button>
        <.button variant="outline" phx-click={@on_cancel || hide_modal(@id)}>
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          Cancel
        </.button>
        <.button variant="outline" phx-click={@on_apply}>
          <:icon><Icons.icon_btn_sounds class="w-4 h-4" /></:icon>
          Apply
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end

  @spec event_label(atom()) :: String.t()
  defp event_label(event), do: Map.get(@event_labels, event, Atom.to_string(event))

  @spec event_sound(map(), atom()) :: String.t()
  defp event_sound(settings, event) do
    settings
    |> Map.get(event, %{})
    |> Map.get(:sound, "Default")
  end

  @spec event_flash(map(), atom()) :: boolean()
  defp event_flash(settings, event) do
    settings
    |> Map.get(event, %{})
    |> Map.get(:flash, false)
  end
end
