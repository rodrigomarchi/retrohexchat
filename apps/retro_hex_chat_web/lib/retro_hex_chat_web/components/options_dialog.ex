defmodule RetroHexChatWeb.Components.OptionsDialog do
  @moduledoc """
  Options dialog component with tree-view navigation and settings panels.
  Windows 98-style dialog with OK/Cancel/Apply pattern using draft state.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Components.NotificationsPanel
  alias RetroHexChatWeb.Icons

  @panels [
    {"display", "Display"},
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
          <Icons.icon_dialog_options class="title-bar-icon" />
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
                <span class="tab-icon">
                  <Icons.icon_tab_display :if={id == "display"} class="btn-icon__svg" />
                  <Icons.icon_tab_notifications :if={id == "notifications"} class="btn-icon__svg" />
                  {label}
                </span>
              </li>
            </ul>
          </div>
          <div class="options-panel" data-testid="options-panel">
            <.display_panel :if={@active_panel == "display"} draft={@options_draft} />
            <NotificationsPanel.notifications_panel
              :if={@active_panel == "notifications"}
              draft={@options_draft}
              channels={@channels}
            />
          </div>
        </div>
        <div class="options-button-bar">
          <button type="button" class="btn-icon" phx-click="options_ok" data-testid="options-ok">
            <Icons.icon_btn_ok class="btn-icon__svg" /> OK
          </button>
          <button
            type="button"
            class="btn-icon"
            phx-click="close_options_dialog"
            data-testid="options-cancel"
          >
            <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
          </button>
          <button type="button" class="btn-icon" phx-click="options_apply" data-testid="options-apply">
            <Icons.icon_btn_apply class="btn-icon__svg" /> Apply
          </button>
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
end
