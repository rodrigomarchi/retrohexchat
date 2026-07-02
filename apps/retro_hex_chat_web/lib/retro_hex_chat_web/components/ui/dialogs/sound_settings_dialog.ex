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
    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_cancel}>
      <.dialog_header id={@id} title={dgettext("dialogs", "Sound Settings")} on_close={@on_cancel}>
        <:icon><Icons.icon_dialog_sound class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body>
        <.sound_settings_panel
          id={@id}
          settings={@settings}
          available_sounds={@available_sounds}
          on_ok={@on_ok}
          on_cancel={@on_cancel}
          on_apply={@on_apply}
          on_sound_change={@on_sound_change}
          on_flash_toggle={@on_flash_toggle}
          on_preview={@on_preview}
          table_class="max-h-[300px]"
        />
      </.dialog_body>
    </.dialog>
    """
  end

  @doc """
  Renders the sound settings content (event/sound table + OK/Cancel/Apply)
  without any frame — compose it inside a dialog or a desktop window body.
  """
  attr :id, :string, required: true
  attr :settings, :map, default: %{}
  attr :available_sounds, :list, default: nil
  attr :on_ok, :any, default: nil
  attr :on_cancel, :any, default: nil
  attr :on_apply, :any, default: nil
  attr :on_sound_change, :any, default: nil
  attr :on_flash_toggle, :any, default: nil
  attr :on_preview, :any, default: nil

  attr :table_class, :any,
    default: nil,
    doc: "extra classes for the scrollable table region (e.g. a max-height cap in a dialog)"

  @spec sound_settings_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def sound_settings_panel(assigns) do
    assigns =
      assigns
      |> assign(:event_order, [
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
      |> assign(:available_sounds, normalize_sound_options(assigns.available_sounds))

    ~H"""
    <div
      id={"#{@id}-content"}
      data-testid="sound-settings-panel"
      class="flex h-full min-h-0 flex-col gap-retro-8"
    >
      <div class={classes(["flex-1 min-h-0 overflow-y-auto retro-scrollbar", @table_class])}>
        <.table>
          <.table_header>
            <.table_row>
              <.table_head>{dgettext("dialogs", "Event")}</.table_head>
              <.table_head>{dgettext("dialogs", "Sound")}</.table_head>
              <.table_head class="w-[60px] text-center">{dgettext("dialogs", "Flash")}</.table_head>
              <.table_head class="w-[80px] text-center">
                {dgettext("dialogs", "Preview")}
              </.table_head>
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
                  {dgettext("dialogs", "Play")}
                </.button>
              </.table_cell>
            </.table_row>
          </.table_body>
        </.table>
      </div>

      <div class="flex justify-end gap-retro-4">
        <.button
          variant="default"
          phx-click={@on_ok}
          data-testid="sound-settings-ok"
        >
          <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
          {dgettext("dialogs", "OK")}
        </.button>
        <.button
          variant="outline"
          phx-click={@on_cancel}
          data-testid="sound-settings-cancel"
        >
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          {dgettext("dialogs", "Cancel")}
        </.button>
        <.button variant="outline" phx-click={@on_apply} data-testid="sound-settings-apply">
          <:icon><Icons.icon_btn_sounds class="w-4 h-4" /></:icon>
          {dgettext("dialogs", "Apply")}
        </.button>
      </div>
    </div>
    """
  end

  @spec event_label(atom()) :: String.t()
  defp event_label(:message), do: dgettext("dialogs", "Channel Message")
  defp event_label(:pm), do: dgettext("dialogs", "Private Message")
  defp event_label(:highlight), do: dgettext("dialogs", "Highlight/Mention")
  defp event_label(:join), do: dgettext("dialogs", "User Joined")
  defp event_label(:part), do: dgettext("dialogs", "User Left")
  defp event_label(:kick), do: dgettext("dialogs", "User Kicked")
  defp event_label(:connect), do: dgettext("dialogs", "Connected")
  defp event_label(:disconnect), do: dgettext("dialogs", "Disconnected")
  defp event_label(:buddy_online), do: dgettext("dialogs", "Buddy Online")
  defp event_label(:buddy_offline), do: dgettext("dialogs", "Buddy Offline")
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
