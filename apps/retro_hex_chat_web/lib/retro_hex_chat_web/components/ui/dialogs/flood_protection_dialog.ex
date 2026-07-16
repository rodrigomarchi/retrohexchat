defmodule RetroHexChatWeb.Components.UI.FloodProtectionDialog do
  @moduledoc """
  Flood protection settings dialog for the showcase design system.

  Composed from dialog + button + input primitives.
  Form-based dialog matching v1 contract: 3 fieldsets (Message Flood,
  Anti-Spam, Auto-Ignore) with correct field names
  submitted via `phx-submit`.

  ## Usage

      <.flood_protection_dialog
        id="flood-protection"
        show={true}
        settings={%{flood_threshold: 5, flood_window_seconds: 10, spam_threshold: 3,
                     spam_window_seconds: 30, auto_ignore_duration_seconds: 60}}
        on_save="flood_save_settings"
        on_reset="flood_reset_defaults"
        on_cancel="close_flood_protection_dialog"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  @default_settings %{
    flood_threshold: 5,
    flood_window_seconds: 10,
    spam_threshold: 3,
    spam_window_seconds: 30,
    auto_ignore_duration_seconds: 60
  }

  @doc "Renders the flood protection settings dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :settings, :map,
    default: @default_settings,
    doc: """
    Flood protection settings map.
    Keys: :flood_threshold, :flood_window_seconds,
          :spam_threshold, :spam_window_seconds,
          :auto_ignore_duration_seconds.
    """

  attr :on_save, :any, default: nil, doc: "Form submit event name"
  attr :on_reset, :any, default: nil, doc: "Reset Defaults button callback"
  attr :on_cancel, :any, default: nil, doc: "Cancel button callback"

  @spec flood_protection_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def flood_protection_dialog(assigns) do
    assigns = assign_new(assigns, :settings, fn -> @default_settings end)

    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_cancel}>
      <.dialog_header id={@id} title={dgettext("dialogs", "Flood Protection")} on_close={@on_cancel}>
        <:icon><Icons.icon_dialog_flood class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body>
        <.flood_protection_panel
          id={@id}
          settings={@settings}
          on_save={@on_save}
          on_reset={@on_reset}
          on_cancel={@on_cancel}
        />
      </.dialog_body>
    </.dialog>
    """
  end

  @doc """
  Renders the flood protection form (3 fieldsets + Save/Reset/Cancel) without
  any frame — compose it inside a dialog or a desktop window body.
  """
  attr :id, :string, required: true
  attr :settings, :map, default: @default_settings
  attr :on_save, :any, default: nil
  attr :on_reset, :any, default: nil
  attr :on_cancel, :any, default: nil

  @spec flood_protection_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def flood_protection_panel(assigns) do
    assigns = assign_new(assigns, :settings, fn -> @default_settings end)

    ~H"""
    <div id={"#{@id}-content"} class="fp-panel" data-testid="flood-protection-panel">
      <form phx-submit={@on_save} class="fp-form">
        <p class="fp-description">
          {dgettext(
            "dialogs",
            "Configure limits to prevent message flooding in channels and private messages."
          )}
        </p>

        <div class="fp-section-grid retro-scrollbar">
          <%!-- Message Flood --%>
          <fieldset class="fp-section">
            <legend class="fp-section-title">{dgettext("dialogs", "Message Flood")}</legend>
            <div class="fp-setting-list">
              <div class="fp-setting-row">
                <label for={"#{@id}-threshold"} class="fp-setting-label">
                  {dgettext("dialogs", "Threshold")}
                </label>
                <div class="fp-setting-control">
                  <.input
                    id={"#{@id}-threshold"}
                    name="flood_threshold"
                    type="number"
                    value={Map.get(@settings, :flood_threshold, 5)}
                    min="1"
                    max="100"
                    class="fp-number-input"
                  />
                  <span class="fp-unit">{dgettext("dialogs", "messages")}</span>
                </div>
              </div>
              <div class="fp-setting-row">
                <label for={"#{@id}-window"} class="fp-setting-label">
                  {dgettext("dialogs", "Time window")}
                </label>
                <div class="fp-setting-control">
                  <.input
                    id={"#{@id}-window"}
                    name="flood_window_seconds"
                    type="number"
                    value={Map.get(@settings, :flood_window_seconds, 10)}
                    min="1"
                    max="300"
                    class="fp-number-input"
                  />
                  <span class="fp-unit">{dgettext("dialogs", "seconds")}</span>
                </div>
              </div>
            </div>
          </fieldset>

          <%!-- Anti-Spam --%>
          <fieldset class="fp-section">
            <legend class="fp-section-title">
              {dgettext("dialogs", "Anti-Spam (Duplicate Detection)")}
            </legend>
            <div class="fp-setting-list">
              <div class="fp-setting-row">
                <label for={"#{@id}-spam-threshold"} class="fp-setting-label">
                  {dgettext("dialogs", "Duplicate limit")}
                </label>
                <div class="fp-setting-control">
                  <.input
                    id={"#{@id}-spam-threshold"}
                    name="spam_threshold"
                    type="number"
                    value={Map.get(@settings, :spam_threshold, 3)}
                    min="1"
                    max="50"
                    class="fp-number-input"
                  />
                  <span class="fp-unit">{dgettext("dialogs", "identical msgs")}</span>
                </div>
              </div>
              <div class="fp-setting-row">
                <label for={"#{@id}-spam-window"} class="fp-setting-label">
                  {dgettext("dialogs", "Time window")}
                </label>
                <div class="fp-setting-control">
                  <.input
                    id={"#{@id}-spam-window"}
                    name="spam_window_seconds"
                    type="number"
                    value={Map.get(@settings, :spam_window_seconds, 30)}
                    min="1"
                    max="120"
                    class="fp-number-input"
                  />
                  <span class="fp-unit">{dgettext("dialogs", "seconds")}</span>
                </div>
              </div>
            </div>
          </fieldset>

          <%!-- Auto-Ignore --%>
          <fieldset class="fp-section">
            <legend class="fp-section-title">{dgettext("dialogs", "Auto-Ignore")}</legend>
            <div class="fp-setting-list">
              <div class="fp-setting-row">
                <label for={"#{@id}-ignore-duration"} class="fp-setting-label">
                  {dgettext("dialogs", "Duration")}
                </label>
                <div class="fp-setting-control">
                  <.input
                    id={"#{@id}-ignore-duration"}
                    name="auto_ignore_duration_seconds"
                    type="number"
                    value={Map.get(@settings, :auto_ignore_duration_seconds, 60)}
                    min="1"
                    max="86400"
                    class="fp-number-input fp-number-input--wide"
                  />
                  <span class="fp-unit">{dgettext("dialogs", "seconds")}</span>
                </div>
              </div>
            </div>
          </fieldset>
        </div>

        <div class="fp-action-row">
          <.button type="submit" variant="default" class="fp-action-button">
            <:icon><Icons.icon_btn_save class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Save")}
          </.button>
          <.button type="button" variant="outline" phx-click={@on_reset} class="fp-action-button">
            <:icon><Icons.icon_btn_reset class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Reset Defaults")}
          </.button>
          <.button type="button" variant="outline" phx-click={@on_cancel} class="fp-action-button">
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Cancel")}
          </.button>
        </div>
      </form>
    </div>
    """
  end
end
