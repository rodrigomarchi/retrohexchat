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
    >
      <div class="window dialog-window--md">
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
        <div class="window-body dialog-body--p8 u-flex-col u-gap-8">
          <fieldset>
            <legend>Event Sounds</legend>
            <div class="u-p-4">
              <table class="table-standard">
                <thead>
                  <tr>
                    <th>Event</th>
                    <th>Sound</th>
                    <th class="u-text-center">Flash</th>
                    <th class="u-text-center"></th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={{event, label} <- @event_labels}>
                    <td class="table-cell--nowrap">{label}</td>
                    <td>
                      <select
                        data-testid={"sound-select-#{event}"}
                        phx-change="sound_settings_change"
                        name={"event_#{event}"}
                        class="u-w-full u-text-sm"
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
                    <td class="u-text-center">
                      <input
                        type="checkbox"
                        data-testid={"flash-toggle-#{event}"}
                        checked={Map.get(@sound_settings_draft.flash_settings, event, false)}
                        phx-click="sound_flash_toggle"
                        phx-value-event={event}
                      />
                    </td>
                    <td class="u-text-center">
                      <button
                        type="button"
                        data-testid={"sound-preview-#{event}"}
                        phx-click="sound_preview"
                        phx-value-event={event}
                        class="btn-xs"
                      >
                        &#9654;
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </fieldset>

          <div class="dialog-buttons u-mt-8">
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
