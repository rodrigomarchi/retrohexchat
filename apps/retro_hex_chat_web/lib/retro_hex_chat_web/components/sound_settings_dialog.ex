defmodule RetroHexChatWeb.Components.SoundSettingsDialog do
  @moduledoc """
  Windows 98-styled dialog for per-event sound and flash configuration.
  OK/Cancel/Apply button pattern with draft state management.
  """
  use Phoenix.Component

  alias RetroHexChat.Chat.SoundSettings

  attr :visible, :boolean, default: false
  attr :sound_settings_draft, :map, default: nil

  @spec sound_settings_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def sound_settings_dialog(assigns) do
    assigns =
      assign(assigns,
        event_labels: event_labels(),
        available_sounds: SoundSettings.available_sounds()
      )

    ~H"""
    <div
      :if={@visible && @sound_settings_draft}
      class="dialog-overlay"
      data-testid="sound-settings-dialog"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 200; background: rgba(0,0,0,0.3);"
    >
      <div class="window" style="width: 420px; min-height: 350px;">
        <div class="title-bar">
          <div class="title-bar-text">Sounds</div>
          <div class="title-bar-controls">
            <button
              aria-label="Close"
              phx-click="close_sound_settings_dialog"
            >
            </button>
          </div>
        </div>
        <div
          class="window-body"
          style="padding: 8px; display: flex; flex-direction: column; gap: 8px;"
        >
          <fieldset>
            <legend>Event Sounds</legend>
            <div style="padding: 4px;">
              <table style="width: 100%; border-collapse: collapse; font-size: 12px;">
                <thead>
                  <tr>
                    <th style="text-align: left; padding: 2px 4px;">Event</th>
                    <th style="text-align: left; padding: 2px 4px;">Sound</th>
                    <th style="text-align: center; padding: 2px 4px;">Flash</th>
                    <th style="text-align: center; padding: 2px 4px;"></th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={{event, label} <- @event_labels}>
                    <td style="padding: 2px 4px; white-space: nowrap;">{label}</td>
                    <td style="padding: 2px 4px;">
                      <select
                        data-testid={"sound-select-#{event}"}
                        phx-change="sound_settings_change"
                        name={"event_#{event}"}
                        style="width: 100%; font-size: 11px;"
                      >
                        <option
                          :for={{name, sound_label} <- @available_sounds}
                          value={name}
                          selected={Map.get(@sound_settings_draft.sound_mappings, event) == name}
                        >
                          {sound_label}
                        </option>
                      </select>
                    </td>
                    <td style="padding: 2px 4px; text-align: center;">
                      <input
                        type="checkbox"
                        data-testid={"flash-toggle-#{event}"}
                        checked={Map.get(@sound_settings_draft.flash_settings, event, false)}
                        phx-click="sound_flash_toggle"
                        phx-value-event={event}
                      />
                    </td>
                    <td style="padding: 2px 4px; text-align: center;">
                      <button
                        type="button"
                        data-testid={"sound-preview-#{event}"}
                        phx-click="sound_preview"
                        phx-value-event={event}
                        style="font-size: 10px; padding: 1px 4px;"
                      >
                        &#9654;
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </fieldset>

          <div style="margin-top: 8px; display: flex; justify-content: flex-end; gap: 4px;">
            <button type="button" phx-click="sound_settings_ok">OK</button>
            <button type="button" phx-click="close_sound_settings_dialog">Cancel</button>
            <button type="button" phx-click="sound_settings_apply">Apply</button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @spec event_labels() :: [{atom(), String.t()}]
  defp event_labels do
    [
      {:message, "Channel Message"},
      {:pm, "Private Message"},
      {:highlight, "Highlight/Mention"},
      {:join, "User Joined"},
      {:part, "User Left"},
      {:kick, "User Kicked"},
      {:connect, "Connected"},
      {:disconnect, "Disconnected"},
      {:buddy_online, "Buddy Online"},
      {:buddy_offline, "Buddy Offline"}
    ]
  end
end
