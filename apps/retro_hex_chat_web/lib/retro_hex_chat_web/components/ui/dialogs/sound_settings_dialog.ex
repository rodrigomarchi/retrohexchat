defmodule RetroHexChatWeb.Components.UI.SoundSettingsDialog do
  @moduledoc """
  Sound event settings dialog component for the showcase design system.

  Composed from dialog + button + checkbox + select primitives.
  Displays IRC events as a responsive settings list with per-event sound
  selection, flash toggle, and preview (play) button. OK/Cancel/Apply footer
  actions.

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
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.Select

  alias RetroHexChat.Chat.SoundSettings
  alias RetroHexChatWeb.Icons

  # A push has to raise a notification, so a browser that will not show one
  # cannot hold a subscription either.
  @blocked_permissions ~w(denied unsupported)

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

  attr :on_notify_toggle, :any,
    default: nil,
    doc: "Desktop-notification checkbox callback (phx-value-event)"

  attr :on_notify_permission_ask, :any,
    default: nil,
    doc: "Callback for the button that asks the browser for permission"

  attr :notify_permission, :string,
    default: "unknown",
    doc: "What the browser last answered: granted, denied, default, unsupported or unknown"

  attr :push_available, :boolean,
    default: false,
    doc: "Whether this server has the keys to send a push at all"

  attr :push_subscribed, :boolean,
    default: false,
    doc: "Whether this browser is already subscribed"

  attr :on_push_toggle, :any, default: nil, doc: "Callback for the closed-app notification toggle"

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
          on_notify_toggle={@on_notify_toggle}
          on_notify_permission_ask={@on_notify_permission_ask}
          notify_permission={@notify_permission}
          push_available={@push_available}
          push_subscribed={@push_subscribed}
          on_push_toggle={@on_push_toggle}
          on_preview={@on_preview}
          table_class="max-h-[300px]"
        />
      </.dialog_body>
    </.dialog>
    """
  end

  @doc """
  Renders the sound settings content (event settings list + OK/Cancel/Apply)
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
  attr :on_notify_toggle, :any, default: nil
  attr :on_notify_permission_ask, :any, default: nil
  attr :notify_permission, :string, default: "unknown"
  attr :push_available, :boolean, default: false
  attr :push_subscribed, :boolean, default: false
  attr :on_push_toggle, :any, default: nil
  attr :on_preview, :any, default: nil

  attr :table_class, :any,
    default: nil,
    doc: "extra classes for the scrollable event list region (e.g. a max-height cap in a dialog)"

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
    <div id={"#{@id}-panel-root"} class="contents">
      <.focus_wrap id={"#{@id}-focus-wrap"} class="contents">
        <div
          id={"#{@id}-content"}
          data-testid="sound-settings-panel"
          role="dialog"
          aria-modal="false"
          tabindex="0"
          phx-mounted={JS.focus(to: "##{@id}-content")}
          class="ss-dialog flex h-full min-h-0 flex-col gap-retro-8"
        >
          <.notify_permission_row
            permission={@notify_permission}
            on_ask={@on_notify_permission_ask}
          />

          <.push_row
            available={@push_available}
            permission={@notify_permission}
            subscribed={@push_subscribed}
            on_toggle={@on_push_toggle}
          />

          <div class={classes(["ss-event-list flex-1 overflow-y-auto retro-scrollbar", @table_class])}>
            <article
              :for={event <- @event_order}
              class="ss-event-entry"
              data-testid={"sound-event-#{event}"}
            >
              <div class="ss-event-header">
                <span class="ss-event-name">{event_label(event)}</span>
                <.button
                  size="sm"
                  variant="outline"
                  phx-click={@on_preview}
                  phx-value-event={event}
                  data-testid={"sound-preview-#{event}"}
                  class="ss-preview-button"
                >
                  <:icon><Icons.icon_btn_sounds class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Play")}
                </.button>
              </div>

              <div class="ss-event-controls">
                <form phx-change={@on_sound_change} class="ss-field ss-select-form">
                  <span class="ss-form-label">{dgettext("dialogs", "Sound")}</span>
                  <.select
                    :let={builder}
                    id={"sound-select-#{event}"}
                    name={"event_#{event}"}
                    value={event_sound(@settings, event)}
                    label={sound_label(@available_sounds, event_sound(@settings, event))}
                    class="w-full"
                    data-testid={"sound-select-#{event}"}
                  >
                    <.select_trigger builder={builder} class="ss-select-trigger h-8 text-xs" />
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

                <label class="ss-toggle-row">
                  <.checkbox
                    id={"flash-toggle-#{event}"}
                    value={event_flash(@settings, event)}
                    phx-click={@on_flash_toggle}
                    phx-value-event={event}
                    data-testid={"flash-toggle-#{event}"}
                  />
                  <span>{dgettext("dialogs", "Flash")}</span>
                </label>

                <label class="ss-toggle-row">
                  <.checkbox
                    id={"notify-toggle-#{event}"}
                    value={event_notify(@settings, event)}
                    phx-click={@on_notify_toggle}
                    phx-value-event={event}
                    data-testid={"notify-toggle-#{event}"}
                  />
                  <span>{dgettext("dialogs", "Notify")}</span>
                </label>
              </div>
            </article>
          </div>

          <div class="ss-dialog-footer flex justify-end gap-retro-4">
            <.button
              variant="default"
              phx-click={@on_ok}
              data-testid="sound-settings-ok"
              class="ss-action-button"
            >
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
            <.button
              variant="outline"
              phx-click={@on_cancel}
              data-testid="sound-settings-cancel"
              class="ss-action-button"
            >
              <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Cancel")}
            </.button>
            <.button
              variant="outline"
              phx-click={@on_apply}
              data-testid="sound-settings-apply"
              class="ss-action-button"
            >
              <:icon><Icons.icon_btn_sounds class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Apply")}
            </.button>
          </div>
        </div>
      </.focus_wrap>
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

  @spec event_notify(map(), atom()) :: boolean()
  defp event_notify(settings, event) do
    settings
    |> normalize_settings()
    |> SoundSettings.get_notify(event)
  end

  defp normalize_settings(%{sound_mappings: _, flash_settings: _} = settings) do
    # A draft seeded before this setting existed carries no notify map at all,
    # and `get_notify/2` on it would answer "off" for everything rather than
    # the defaults the person actually has.
    Map.put_new(settings, :notify_settings, SoundSettings.get_notify_settings(%{}))
  end

  defp normalize_settings(_settings), do: SoundSettings.new()

  attr :permission, :string, required: true
  attr :on_ask, :any, default: nil

  # What the browser last answered, and the one action that can change it.
  # "Denied" is final until the person changes it in their own settings, so the
  # window explains rather than offering a button that cannot work.
  defp notify_permission_row(assigns) do
    ~H"""
    <p
      :if={@permission == "denied"}
      class="ss-permission-note"
      data-testid="notify-permission-denied"
    >
      {dgettext(
        "dialogs",
        "Your browser is blocking notifications for this site. Allow them in the browser's site settings to turn these on."
      )}
    </p>
    <p
      :if={@permission == "unsupported"}
      class="ss-permission-note"
      data-testid="notify-permission-unsupported"
    >
      {dgettext("dialogs", "This browser cannot show desktop notifications.")}
    </p>
    <div :if={@permission == "default"} class="ss-permission-note">
      <.button
        size="sm"
        variant="outline"
        phx-click={@on_ask}
        data-testid="notify-permission-ask"
      >
        <:icon><Icons.icon_megaphone class="w-4 h-4" /></:icon>
        {dgettext("dialogs", "Allow desktop notifications")}
      </.button>
    </div>
    """
  end

  attr :available, :boolean, required: true
  attr :permission, :string, required: true
  attr :subscribed, :boolean, required: true
  attr :on_toggle, :any, default: nil

  # The one notification that survives the tab being closed, and the only one
  # that leaves this server. Two things can make it impossible, and either one
  # removes the row rather than drawing a switch that cannot work: a server with
  # no VAPID keys, and a browser that has blocked notifications — a push is
  # required to show one, so a blocked browser refuses the subscription outright.
  defp push_row(assigns) do
    assigns =
      assign(
        assigns,
        :offered,
        assigns.available and assigns.permission not in @blocked_permissions
      )

    ~H"""
    <label :if={@offered} class="ss-toggle-row ss-push-row" data-testid="push-row">
      <.checkbox
        id="push-toggle"
        value={@subscribed}
        phx-click={@on_toggle}
        data-testid="push-toggle"
      />
      <span>
        {dgettext("dialogs", "Notify me on this device even when Retro Hex Chat is closed")}
      </span>
    </label>
    """
  end

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
