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

  alias RetroHexChat.Chat.SoundSettings
  alias RetroHexChatWeb.Icons

  @doc "Renders the sound settings dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :settings, :map,
    default: %{},
    doc: "SoundSettings map containing sound_mappings and flash_settings"

  attr :available_sounds, :list,
    default: nil,
    doc: "Sound options for the dropdown as {value, label} tuples"

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
      |> assign(
        :available_sounds,
        normalize_sound_options(assigns.available_sounds)
      )

    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_cancel}>
      <.dialog_header id={@id} title={gettext("Sound Settings")} on_close={@on_cancel}>
        <:icon><Icons.icon_dialog_sound class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body>
        <div class="max-h-[300px] overflow-y-auto retro-scrollbar">
          <.table>
            <.table_header>
              <.table_row>
                <.table_head>{gettext("Event")}</.table_head>
                <.table_head>{gettext("Sound")}</.table_head>
                <.table_head class="w-[60px] text-center">{gettext("Flash")}</.table_head>
                <.table_head class="w-[80px] text-center">{gettext("Preview")}</.table_head>
              </.table_row>
            </.table_header>
            <.table_body>
              <.table_row :for={event <- @event_order}>
                <.table_cell class="font-bold text-xs">
                  {event_label(event)}
                </.table_cell>

                <.table_cell>
                  <form phx-change={@on_sound_change}>
                    <.select
                      :let={builder}
                      id={"sound-select-#{event}"}
                      name={"event_#{event}"}
                      value={event_sound(@settings, event)}
                      label={sound_label(@available_sounds, event_sound(@settings, event))}
                      class="w-full"
                      data-testid={"sound-select-#{event}"}
                    >
                      <.select_trigger builder={builder} class="h-8 text-xs" />
                      <.select_content builder={builder}>
                        <.select_group>
                          <.select_item
                            :for={{sound, label} <- @available_sounds}
                            builder={builder}
                            value={sound}
                            label={label}
                            on_select={@on_sound_change}
                            on_select_value={%{event: event, sound: sound}}
                          >
                            {label}
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
                    data-testid={"flash-toggle-#{event}"}
                  />
                </.table_cell>

                <.table_cell class="text-center">
                  <.button
                    size="sm"
                    variant="outline"
                    phx-click={@on_preview}
                    phx-value-event={event}
                    data-testid={"sound-preview-#{event}"}
                  >
                    <:icon><Icons.icon_btn_sounds class="w-4 h-4" /></:icon>
                    {gettext("Play")}
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
          {gettext("OK")}
        </.button>
        <.button variant="outline" phx-click={@on_cancel || hide_modal(@id)}>
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          {gettext("Cancel")}
        </.button>
        <.button variant="outline" phx-click={@on_apply}>
          <:icon><Icons.icon_btn_sounds class="w-4 h-4" /></:icon>
          {gettext("Apply")}
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end

  @spec event_label(atom()) :: String.t()
  defp event_label(:message), do: gettext("Channel Message")
  defp event_label(:pm), do: gettext("Private Message")
  defp event_label(:highlight), do: gettext("Highlight/Mention")
  defp event_label(:join), do: gettext("User Joined")
  defp event_label(:part), do: gettext("User Left")
  defp event_label(:kick), do: gettext("User Kicked")
  defp event_label(:connect), do: gettext("Connected")
  defp event_label(:disconnect), do: gettext("Disconnected")
  defp event_label(:buddy_online), do: gettext("Buddy Online")
  defp event_label(:buddy_offline), do: gettext("Buddy Offline")
  defp event_label(event), do: Atom.to_string(event)

  @spec event_sound(map(), atom()) :: String.t()
  defp event_sound(settings, event) do
    settings
    |> normalize_settings()
    |> SoundSettings.get_sound(event)
  end

  @spec event_flash(map(), atom()) :: boolean()
  defp event_flash(settings, event) do
    settings
    |> normalize_settings()
    |> SoundSettings.get_flash(event)
  end

  defp normalize_settings(%{sound_mappings: _, flash_settings: _} = settings), do: settings
  defp normalize_settings(_settings), do: SoundSettings.new()

  defp normalize_sound_options(nil), do: SoundSettings.available_sounds()

  defp normalize_sound_options(options) do
    Enum.map(options, fn
      {value, label} -> {value, label}
      value when is_binary(value) -> {value, value}
    end)
  end

  defp sound_label(options, value) do
    options
    |> Enum.find_value(value, fn
      {^value, label} -> label
      _ -> nil
    end)
  end
end
