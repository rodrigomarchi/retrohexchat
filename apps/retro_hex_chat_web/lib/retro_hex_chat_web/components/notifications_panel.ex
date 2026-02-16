defmodule RetroHexChatWeb.Components.NotificationsPanel do
  @moduledoc """
  Notifications panel for the Options dialog.
  Global toggles, trigger rules, per-channel notification levels.
  """
  use Phoenix.Component

  attr :draft, :map, required: true
  attr :channels, :list, default: []

  @spec notifications_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def notifications_panel(assigns) do
    notif = assigns.draft.notifications

    assigns =
      assigns
      |> assign(:notif, notif)
      |> assign(:sorted_channels, Enum.sort(assigns.channels))

    ~H"""
    <div data-testid="options-notifications-panel">
      <fieldset>
        <legend>Global Toggles</legend>
        <.notif_checkbox
          id="opt-notif-sounds"
          label="Sound notifications"
          checked={@notif.sounds_enabled}
          setting="sounds_enabled"
        />
        <.notif_checkbox
          id="opt-notif-title-flash"
          label="Title flash"
          checked={@notif.title_flash_enabled}
          setting="title_flash_enabled"
        />
        <.notif_checkbox
          id="opt-notif-browser"
          label="Browser notifications"
          checked={@notif.browser_notifications}
          setting="browser_notifications"
        />
        <div class="field-row u-ml-8">
          <button
            type="button"
            phx-click="request_browser_permission"
            data-testid="request-browser-permission"
          >
            Request Permission
          </button>
        </div>
        <.notif_checkbox
          id="opt-notif-privacy"
          label="Privacy mode (hide message content)"
          checked={@notif.privacy_mode}
          setting="privacy_mode"
        />
        <.notif_checkbox
          id="opt-notif-dnd"
          label="Do Not Disturb"
          checked={@notif.dnd_enabled}
          setting="dnd_enabled"
        />
      </fieldset>

      <fieldset>
        <legend>Notify When</legend>
        <.notif_checkbox
          id="opt-notif-trigger-mentions"
          label="Someone mentions my nick"
          checked={@notif.trigger_mentions}
          setting="trigger_mentions"
        />
        <.notif_checkbox
          id="opt-notif-trigger-pms"
          label="I receive a PM"
          checked={@notif.trigger_pms}
          setting="trigger_pms"
        />
        <.notif_checkbox
          id="opt-notif-trigger-channel"
          label="Any message in a channel"
          checked={@notif.trigger_channel_messages}
          setting="trigger_channel_messages"
        />
        <.notif_checkbox
          id="opt-notif-trigger-joins"
          label="Someone joins/leaves"
          checked={@notif.trigger_joins_leaves}
          setting="trigger_joins_leaves"
        />
      </fieldset>

      <fieldset :if={@sorted_channels != []}>
        <legend>Per-Channel Levels</legend>
        <div class="field-row">
          <label>PMs:</label>
          <select disabled data-testid="notif-channel-level-pms">
            <option selected>Always</option>
          </select>
        </div>
        <div :for={channel <- @sorted_channels} class="field-row">
          <label>{channel}:</label>
          <select
            phx-change="options_change_channel_level"
            name={"channel_level_#{channel}"}
            data-testid={"notif-channel-level-#{channel}"}
          >
            <option value="normal" selected={channel_level(@notif, channel) == :normal}>
              Normal
            </option>
            <option value="mentions_only" selected={channel_level(@notif, channel) == :mentions_only}>
              Mentions only
            </option>
            <option value="mute" selected={channel_level(@notif, channel) == :mute}>
              Mute
            </option>
          </select>
        </div>
      </fieldset>
    </div>
    """
  end

  defp notif_checkbox(assigns) do
    ~H"""
    <div class="field-row">
      <input
        type="checkbox"
        id={@id}
        checked={@checked}
        phx-click="options_toggle_notification"
        phx-value-setting={@setting}
        data-testid={"notif-#{@setting}"}
      />
      <label for={@id}>{@label}</label>
    </div>
    """
  end

  defp channel_level(notif, channel) do
    Map.get(notif.channel_levels, channel, :normal)
  end
end
