defmodule RetroHexChatWeb.Components.OptionsDialog do
  @moduledoc """
  Options dialog component with tree-view navigation and settings panels.
  Windows 98-style dialog with OK/Cancel/Apply pattern using draft state.
  """
  use Phoenix.Component

  alias RetroHexChat.Chat.KeyBindings
  alias RetroHexChatWeb.Components.NotificationsPanel

  @panels [
    {"messages", "IRC Messages"},
    {"display", "Display"},
    {"keybindings", "Key Bindings"},
    {"notifications", "Notifications"}
  ]

  attr :visible, :boolean, default: false
  attr :active_panel, :string, default: "display"
  attr :options_draft, :map, default: nil
  attr :channels, :list, default: []

  @spec options_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def options_dialog(assigns) do
    assigns = assign(assigns, :panels, @panels)

    ~H"""
    <div
      :if={@visible && @options_draft}
      class="dialog-overlay options-dialog-overlay"
      data-testid="options-dialog-overlay"
    >
      <div class="window options-dialog" data-testid="options-dialog">
        <div class="title-bar">
          <div class="title-bar-text">Options</div>
          <div class="title-bar-controls">
            <button type="button" aria-label="Close" phx-click="close_options_dialog"></button>
          </div>
        </div>
        <div class="window-body options-dialog-body">
          <div class="options-nav">
            <ul class="tree-view" data-testid="options-tree">
              <li
                :for={{id, label} <- @panels}
                class={if @active_panel == id, do: "tree-item-selected", else: ""}
                phx-click="options_select_panel"
                phx-value-panel={id}
                data-testid={"options-tree-#{id}"}
              >
                {label}
              </li>
            </ul>
          </div>
          <div class="options-panel" data-testid="options-panel">
            <.display_panel :if={@active_panel == "display"} draft={@options_draft} />
            <.messages_panel :if={@active_panel == "messages"} draft={@options_draft} />
            <.keybindings_panel :if={@active_panel == "keybindings"} draft={@options_draft} />
            <NotificationsPanel.notifications_panel
              :if={@active_panel == "notifications"}
              draft={@options_draft}
              channels={@channels}
            />
          </div>
        </div>
        <div class="options-button-bar">
          <button type="button" phx-click="options_ok" data-testid="options-ok">OK</button>
          <button type="button" phx-click="close_options_dialog" data-testid="options-cancel">
            Cancel
          </button>
          <button type="button" phx-click="options_apply" data-testid="options-apply">Apply</button>
        </div>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Display Panel
  # ---------------------------------------------------------------------------

  defp display_panel(assigns) do
    ~H"""
    <div data-testid="options-display-panel">
      <fieldset>
        <legend>UI Elements</legend>
        <.display_checkbox
          id="opt-show-toolbar"
          label="Show Toolbar"
          checked={@draft.display.show_toolbar}
          setting="show_toolbar"
        />
        <.display_checkbox
          id="opt-show-treebar"
          label="Show Treebar"
          checked={@draft.display.show_treebar}
          setting="show_treebar"
        />
        <.display_checkbox
          id="opt-show-switchbar"
          label="Show Switchbar (Tab Bar)"
          checked={@draft.display.show_switchbar}
          setting="show_switchbar"
        />
        <.display_checkbox
          id="opt-show-statusbar"
          label="Show Status Bar"
          checked={@draft.display.show_statusbar}
          setting="show_statusbar"
        />
      </fieldset>
      <fieldset>
        <legend>Appearance</legend>
        <.display_checkbox
          id="opt-compact-mode"
          label="Compact Mode"
          checked={@draft.display.compact_mode}
          setting="compact_mode"
        />
        <.display_checkbox
          id="opt-line-shading"
          label="Line Shading"
          checked={@draft.display.line_shading}
          setting="line_shading"
        />
        <.display_checkbox
          id="opt-show-contextual-tips"
          label="Mostrar dicas contextuais"
          checked={@draft.display.show_contextual_tips}
          setting="show_contextual_tips"
        />
      </fieldset>
      <fieldset>
        <legend>Timestamps</legend>
        <div class="field-row">
          <label for="opt-timestamp-format">Format:</label>
          <select
            id="opt-timestamp-format"
            phx-change="options_change_timestamp_format"
            name="timestamp_format"
            data-testid="options-display-timestamp-format"
          >
            <option
              value="hh_mm"
              selected={Map.get(@draft.display, :timestamp_format, :hh_mm) == :hh_mm}
            >
              [HH:MM]
            </option>
            <option
              value="hh_mm_ss"
              selected={Map.get(@draft.display, :timestamp_format, :hh_mm) == :hh_mm_ss}
            >
              [HH:MM:SS]
            </option>
            <option
              value="dd_mm_hh_mm"
              selected={Map.get(@draft.display, :timestamp_format, :hh_mm) == :dd_mm_hh_mm}
            >
              [DD/MM HH:MM]
            </option>
            <option
              value="none"
              selected={Map.get(@draft.display, :timestamp_format, :hh_mm) == :none}
            >
              None
            </option>
          </select>
        </div>
      </fieldset>
      <fieldset>
        <legend>Disconnect</legend>
        <div class="field-row">
          <label for="opt-quit-message">Default quit message:</label>
          <input
            type="text"
            id="opt-quit-message"
            value={Map.get(@draft.display, :quit_message, "Leaving")}
            maxlength="200"
            phx-blur="options_change_quit_message"
            phx-keyup="options_change_quit_message"
            phx-key="Enter"
            name="quit_message"
            class="options-quit-input"
            data-testid="options-display-quit-message"
          />
        </div>
      </fieldset>
      <fieldset>
        <legend>Command Help</legend>
        <div class="field-row">
          <label>Detail level for command syntax tooltip:</label>
        </div>
        <div class="field-row">
          <input
            type="radio"
            id="opt-help-beginner"
            name="command_help_level"
            value="beginner"
            checked={Map.get(@draft.display, :command_help_level, :beginner) == :beginner}
            phx-click="update_command_help_level"
            phx-value-level="beginner"
            data-testid="options-help-beginner"
          />
          <label for="opt-help-beginner">Beginner (full descriptions and examples)</label>
        </div>
        <div class="field-row">
          <input
            type="radio"
            id="opt-help-expert"
            name="command_help_level"
            value="expert"
            checked={Map.get(@draft.display, :command_help_level, :beginner) == :expert}
            phx-click="update_command_help_level"
            phx-value-level="expert"
            data-testid="options-help-expert"
          />
          <label for="opt-help-expert">Expert (syntax line only)</label>
        </div>
        <div class="field-row">
          <input
            type="radio"
            id="opt-help-off"
            name="command_help_level"
            value="off"
            checked={Map.get(@draft.display, :command_help_level, :beginner) == :off}
            phx-click="update_command_help_level"
            phx-value-level="off"
            data-testid="options-help-off"
          />
          <label for="opt-help-off">Off (disable tooltip)</label>
        </div>
      </fieldset>
    </div>
    """
  end

  defp display_checkbox(assigns) do
    ~H"""
    <div class="field-row">
      <input
        type="checkbox"
        id={@id}
        checked={@checked}
        phx-click="options_toggle_display"
        phx-value-setting={@setting}
        data-testid={"options-display-#{@setting}"}
      />
      <label for={@id}>{@label}</label>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # IRC Messages Panel
  # ---------------------------------------------------------------------------

  defp messages_panel(assigns) do
    ~H"""
    <div data-testid="options-messages-panel">
      <fieldset>
        <legend>Message Routing</legend>
        <div class="field-row">
          <label for="opt-notice-routing">Notices:</label>
          <select
            id="opt-notice-routing"
            phx-change="options_change_routing"
            name="notice_routing"
            data-testid="options-messages-notice-routing"
          >
            <option value="active" selected={@draft.messages.notice_routing == :active}>
              Active Window
            </option>
            <option value="status" selected={@draft.messages.notice_routing == :status}>
              Status Window
            </option>
            <option value="sender" selected={@draft.messages.notice_routing == :sender}>
              Sender Window
            </option>
          </select>
        </div>
      </fieldset>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Key Bindings Panel
  # ---------------------------------------------------------------------------

  defp keybindings_panel(assigns) do
    actions = KeyBindings.actions()
    assigns = assign(assigns, :actions, actions)

    ~H"""
    <div data-testid="options-keybindings-panel">
      <fieldset>
        <legend>Keyboard Shortcuts</legend>
        <div class="keybindings-list" data-testid="keybindings-list">
          <div
            :for={{action, label} <- @actions}
            class="keybinding-row"
            data-testid={"keybinding-#{action}"}
          >
            <span class="keybinding-action">{label}</span>
            <span class="keybinding-combo">
              {format_binding(@draft.key_bindings, action)}
            </span>
          </div>
        </div>
      </fieldset>
      <div class="keybindings-actions">
        <button
          type="button"
          phx-click="options_reset_bindings"
          data-testid="options-reset-bindings"
        >
          Reset to Defaults
        </button>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp format_binding(bindings, action) do
    case Map.get(bindings, action) do
      nil -> "(unbound)"
      binding -> KeyBindings.to_display_string(binding)
    end
  end
end
