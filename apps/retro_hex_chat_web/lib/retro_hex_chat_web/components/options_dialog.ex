defmodule RetroHexChatWeb.Components.OptionsDialog do
  @moduledoc """
  Options dialog component with tree-view navigation and settings panels.
  Windows 98-style dialog with OK/Cancel/Apply pattern using draft state.
  """
  use Phoenix.Component

  alias RetroHexChat.Chat.KeyBindings
  alias RetroHexChat.Chat.UserPreferences

  @panels [
    {"connect", "Connect"},
    {"messages", "IRC Messages"},
    {"display", "Display"},
    {"fonts", "Fonts"},
    {"colors", "Colors"},
    {"keybindings", "Key Bindings"}
  ]

  attr :visible, :boolean, default: false
  attr :active_panel, :string, default: "display"
  attr :options_draft, :map, default: nil

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
            <.fonts_panel :if={@active_panel == "fonts"} draft={@options_draft} />
            <.colors_panel :if={@active_panel == "colors"} draft={@options_draft} />
            <.connect_panel :if={@active_panel == "connect"} draft={@options_draft} />
            <.messages_panel :if={@active_panel == "messages"} draft={@options_draft} />
            <.keybindings_panel :if={@active_panel == "keybindings"} draft={@options_draft} />
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
  # Fonts Panel
  # ---------------------------------------------------------------------------

  defp fonts_panel(assigns) do
    font_families = UserPreferences.valid_font_families()
    assigns = assign(assigns, :font_families, font_families)

    ~H"""
    <div data-testid="options-fonts-panel">
      <.font_area
        label="Chat Messages"
        area="chat_messages"
        font={@draft.fonts.chat_messages}
        families={@font_families}
      />
      <.font_area
        label="Input Box"
        area="input_box"
        font={@draft.fonts.input_box}
        families={@font_families}
      />
      <.font_area
        label="Nicklist"
        area="nicklist"
        font={@draft.fonts.nicklist}
        families={@font_families}
      />
      <.font_area
        label="Treebar"
        area="treebar"
        font={@draft.fonts.treebar}
        families={@font_families}
      />
      <fieldset>
        <legend>Preview</legend>
        <div
          class="font-preview"
          style={"font-family: #{@draft.fonts.chat_messages.family}; font-size: #{@draft.fonts.chat_messages.size}px;"}
          data-testid="font-preview"
        >
          [12:34] &lt;Alice&gt; Hello! The quick brown fox jumps over the lazy dog.
        </div>
      </fieldset>
    </div>
    """
  end

  defp font_area(assigns) do
    sizes = Enum.to_list(8..24)
    assigns = assign(assigns, :sizes, sizes)

    ~H"""
    <fieldset>
      <legend>{@label}</legend>
      <div class="field-row">
        <label>Family:</label>
        <select
          phx-change="options_change_font"
          data-testid={"options-font-family-#{@area}"}
          name={"font_family_#{@area}"}
        >
          <option
            :for={family <- @families}
            value={family}
            selected={@font.family == family}
          >
            {short_family_name(family)}
          </option>
        </select>
      </div>
      <div class="field-row">
        <label>Size:</label>
        <select
          phx-change="options_change_font"
          data-testid={"options-font-size-#{@area}"}
          name={"font_size_#{@area}"}
        >
          <option :for={size <- @sizes} value={size} selected={@font.size == size}>
            {size}px
          </option>
        </select>
      </div>
    </fieldset>
    """
  end

  # ---------------------------------------------------------------------------
  # Colors Panel
  # ---------------------------------------------------------------------------

  defp colors_panel(assigns) do
    color_palette = color_picker_palette()
    assigns = assign(assigns, :palette, color_palette)

    ~H"""
    <div data-testid="options-colors-panel">
      <fieldset>
        <legend>Message Colors</legend>
        <.color_slot
          label="Chat Background"
          slot="chat_background"
          color={@draft.colors.chat_background}
          palette={@palette}
        />
        <.color_slot
          label="Default Text"
          slot="default_text"
          color={@draft.colors.default_text}
          palette={@palette}
        />
        <.color_slot
          label="Own Messages"
          slot="own_messages"
          color={@draft.colors.own_messages}
          palette={@palette}
        />
        <.color_slot
          label="System Messages"
          slot="system_messages"
          color={@draft.colors.system_messages}
          palette={@palette}
        />
        <.color_slot
          label="Timestamps"
          slot="timestamps"
          color={@draft.colors.timestamps}
          palette={@palette}
        />
        <.color_slot
          label="Error Messages"
          slot="error_messages"
          color={@draft.colors.error_messages}
          palette={@palette}
        />
      </fieldset>
      <fieldset>
        <legend>Nick Colors (IRC Palette)</legend>
        <div class="nick-palette-grid" data-testid="nick-palette-grid">
          <div
            :for={{color, idx} <- Enum.with_index(@draft.colors.nick_palette)}
            class="nick-palette-swatch"
            style={"background-color: #{color};"}
            phx-click="options_select_nick_color"
            phx-value-index={idx}
            data-testid={"nick-palette-#{idx}"}
            title={"Color #{idx}: #{color}"}
          >
          </div>
        </div>
      </fieldset>
    </div>
    """
  end

  defp color_slot(assigns) do
    ~H"""
    <div class="color-slot-row" data-testid={"options-color-#{@slot}"}>
      <span class="color-swatch" style={"background-color: #{@color};"}></span>
      <span class="color-slot-label">{@label}</span>
      <div class="color-picker-grid">
        <div
          :for={hex <- @palette}
          class="color-picker-cell"
          style={"background-color: #{hex};"}
          phx-click="options_change_color"
          phx-value-slot={@slot}
          phx-value-color={hex}
          title={hex}
        >
        </div>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Connect Panel
  # ---------------------------------------------------------------------------

  defp connect_panel(assigns) do
    ~H"""
    <div data-testid="options-connect-panel">
      <fieldset>
        <legend>Auto-Reconnect</legend>
        <div class="field-row">
          <input
            type="checkbox"
            id="opt-auto-reconnect"
            checked={@draft.connect.auto_reconnect_enabled}
            phx-click="options_change_connect"
            phx-value-setting="auto_reconnect_enabled"
            phx-value-value={to_string(!@draft.connect.auto_reconnect_enabled)}
            data-testid="options-connect-auto-reconnect"
          />
          <label for="opt-auto-reconnect">Enable auto-reconnect</label>
        </div>
        <div class="field-row">
          <label for="opt-retry-interval">Retry interval (seconds):</label>
          <input
            type="number"
            id="opt-retry-interval"
            value={@draft.connect.retry_interval}
            min="1"
            max="60"
            phx-change="options_change_connect_number"
            name="retry_interval"
            data-testid="options-connect-retry-interval"
          />
        </div>
        <div class="field-row">
          <label for="opt-max-retries">Maximum retries:</label>
          <input
            type="number"
            id="opt-max-retries"
            value={@draft.connect.max_retries}
            min="1"
            max="100"
            phx-change="options_change_connect_number"
            name="max_retries"
            data-testid="options-connect-max-retries"
          />
        </div>
        <div class="field-row">
          <label for="opt-connection-timeout">Connection timeout (seconds):</label>
          <input
            type="number"
            id="opt-connection-timeout"
            value={@draft.connect.connection_timeout}
            min="5"
            max="120"
            phx-change="options_change_connect_number"
            name="connection_timeout"
            data-testid="options-connect-timeout"
          />
        </div>
      </fieldset>
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
          <label for="opt-whois-routing">Whois results:</label>
          <select
            id="opt-whois-routing"
            phx-change="options_change_routing"
            name="whois_routing"
            data-testid="options-messages-whois-routing"
          >
            <option value="active" selected={@draft.messages.whois_routing == :active}>
              Active Window
            </option>
            <option value="dialog" selected={@draft.messages.whois_routing == :dialog}>
              Whois Dialog
            </option>
          </select>
        </div>
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
        <div class="field-row">
          <label for="opt-pm-routing">Private Messages:</label>
          <select
            id="opt-pm-routing"
            phx-change="options_change_routing"
            name="pm_routing"
            data-testid="options-messages-pm-routing"
          >
            <option value="new_tab" selected={@draft.messages.pm_routing == :new_tab}>
              Open New Tab
            </option>
            <option value="active" selected={@draft.messages.pm_routing == :active}>
              Active Window
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

  defp short_family_name(family) do
    family
    |> String.split(",")
    |> List.first()
    |> String.trim()
    |> String.replace("\"", "")
  end

  defp color_picker_palette do
    # 16 standard IRC colors + 8 additional presets = 24 total
    [
      "#ffffff",
      "#000000",
      "#00007f",
      "#009300",
      "#ff0000",
      "#7f0000",
      "#9c009c",
      "#fc7f00",
      "#ffff00",
      "#00fc00",
      "#009393",
      "#00ffff",
      "#0000fc",
      "#ff00ff",
      "#7f7f7f",
      "#d2d2d2",
      "#c0c0c0",
      "#808000",
      "#008080",
      "#000080",
      "#800080",
      "#808080",
      "#400000",
      "#ffa500"
    ]
  end

  defp format_binding(bindings, action) do
    case Map.get(bindings, action) do
      nil -> "(unbound)"
      binding -> KeyBindings.to_display_string(binding)
    end
  end
end
