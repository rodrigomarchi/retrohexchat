defmodule RetroHexChatWeb.Components.UI.PerformDialog do
  @moduledoc """
  Win98-style Perform dialog component for the showcase design system.

  Manages the commands executed automatically on connect: add, edit, remove,
  reorder, and the master enable toggle.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.Separator
  import RetroHexChatWeb.Components.UI.Textarea

  alias RetroHexChatWeb.Icons

  @doc """
  Renders a framed Win98-style Perform dialog. Used by the showcase; the desktop
  window mounts `perform_panel/1` instead.

  ## Examples

      <.perform_dialog
        id="perform"
        show={true}
        entries={[%{position: 1, command: "/join #lobby"}]}
      />
  """
  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :show, :boolean, default: false
  attr :entries, :list, default: []
  attr :selected, :integer, default: nil
  attr :enabled, :boolean, default: true
  attr :show_add_dialog, :boolean, default: false
  attr :show_edit_dialog, :boolean, default: false
  attr :on_select, :any, default: nil
  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_remove, :any, default: nil
  attr :on_move_up, :any, default: nil
  attr :on_move_down, :any, default: nil
  attr :on_toggle_enabled, :any, default: nil
  attr :on_ok, :any, default: nil
  attr :on_cancel, :any, default: nil

  @spec perform_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def perform_dialog(assigns) do
    ~H"""
    <.dialog
      id={@id}
      show={@show}
      lock={@show_add_dialog || @show_edit_dialog}
      on_cancel={@on_cancel}
    >
      <.dialog_header id={@id} title={dgettext("dialogs", "Perform")} on_close={@on_cancel}>
        <:icon><Icons.icon_dialog_perform /></:icon>
      </.dialog_header>
      <.dialog_body>
        <.perform_panel
          id={@id}
          target={@target}
          entries={@entries}
          selected={@selected}
          enabled={@enabled}
          show_add_dialog={@show_add_dialog}
          show_edit_dialog={@show_edit_dialog}
          on_select={@on_select}
          on_add={@on_add}
          on_edit={@on_edit}
          on_remove={@on_remove}
          on_move_up={@on_move_up}
          on_move_down={@on_move_down}
          on_toggle_enabled={@on_toggle_enabled}
          sub_scope={:viewport}
        />
      </.dialog_body>
      <.dialog_footer>
        <.button phx-click={@on_ok}>
          <:icon><Icons.icon_checkmark /></:icon>
          {dgettext("dialogs", "OK")}
        </.button>
        <.button variant="outline" phx-click={@on_cancel || hide_modal(@id)}>
          <:icon><Icons.icon_close /></:icon>
          {dgettext("dialogs", "Cancel")}
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end

  @doc """
  Renders the Perform content (command list + the add/edit sub-form modals)
  without any frame — compose it inside a dialog or a desktop window body.
  `sub_scope` decides where the sub-form modals anchor.
  """
  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :entries, :list, default: []
  attr :selected, :integer, default: nil
  attr :enabled, :boolean, default: true
  attr :show_add_dialog, :boolean, default: false
  attr :show_edit_dialog, :boolean, default: false
  attr :on_select, :any, default: nil
  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_remove, :any, default: nil
  attr :on_move_up, :any, default: nil
  attr :on_move_down, :any, default: nil
  attr :on_toggle_enabled, :any, default: nil
  attr :on_close, :any, default: nil
  attr :sub_scope, :atom, default: :window, values: [:viewport, :window]

  @spec perform_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def perform_panel(assigns) do
    first_pos = if assigns.entries != [], do: List.first(assigns.entries).position, else: nil
    last_pos = if assigns.entries != [], do: List.last(assigns.entries).position, else: nil

    assigns =
      assign(assigns,
        first_pos: first_pos,
        last_pos: last_pos,
        has_selection: assigns.selected != nil
      )

    ~H"""
    <div id={@id} class="contents">
      <.focus_wrap id={"#{@id}-focus-wrap"} class="contents">
        <div
          id={"#{@id}-content"}
          data-testid="perform-panel"
          role="dialog"
          aria-modal="false"
          tabindex="0"
          phx-mounted={JS.focus(to: "##{@id}-content")}
          class="pf-dialog flex h-full min-h-0 flex-col gap-retro-8"
        >
          <div class="pf-entry-list min-h-0 flex-1 overflow-y-auto">
            <div :if={@entries == []} class="pf-empty-state text-center text-muted-foreground">
              {dgettext("dialogs", "No commands configured. Click Add to create one.")}
            </div>

            <button
              :for={entry <- @entries}
              type="button"
              data-testid="perform-command-row"
              data-position={entry.position}
              aria-pressed={@selected == entry.position}
              class={row_class(@selected == entry.position)}
              phx-click={@on_select}
              phx-target={@target}
              phx-value-position={entry.position}
            >
              <span class="pf-entry-index">{entry.position}</span>
              <span class="pf-entry-content">
                <span class="pf-entry-label">{mask_command(entry.command)}</span>
                <span class="pf-entry-meta">
                  {dgettext("dialogs", "Position")} {entry.position}
                </span>
              </span>
            </button>
          </div>

          <div class="pf-action-row flex gap-1">
            <.button size="sm" phx-click={@on_add} phx-target={@target} class="pf-action-button">
              <:icon><Icons.icon_btn_add /></:icon>
              {dgettext("dialogs", "Add")}
            </.button>
            <.button
              size="sm"
              phx-click={@on_edit}
              phx-target={@target}
              disabled={!@has_selection}
              class="pf-action-button"
            >
              <:icon><Icons.icon_btn_edit /></:icon>
              {dgettext("dialogs", "Edit")}
            </.button>
            <.button
              size="sm"
              variant="destructive"
              phx-click={@on_remove}
              phx-target={@target}
              disabled={!@has_selection}
              class="pf-action-button"
            >
              <:icon><Icons.icon_btn_remove /></:icon>
              {dgettext("dialogs", "Remove")}
            </.button>
            <.button
              size="sm"
              variant="outline"
              phx-click={@on_move_up}
              phx-target={@target}
              disabled={!@has_selection || @selected == @first_pos}
              class="pf-action-button"
            >
              <:icon><Icons.icon_btn_up /></:icon>
              {dgettext("dialogs", "Up")}
            </.button>
            <.button
              size="sm"
              variant="outline"
              phx-click={@on_move_down}
              phx-target={@target}
              disabled={!@has_selection || @selected == @last_pos}
              class="pf-action-button"
            >
              <:icon><Icons.icon_btn_down /></:icon>
              {dgettext("dialogs", "Down")}
            </.button>
          </div>

          <.separator class="my-2" />

          <label class="pf-toggle-row inline-flex items-center gap-2 text-xs cursor-pointer">
            <.checkbox
              name="perform_enabled"
              value={@enabled}
              phx-click={@on_toggle_enabled}
              phx-target={@target}
            /> {dgettext("dialogs", "Enable perform on connect")}
          </label>

          <div :if={@on_close} class="pf-dialog-footer flex justify-end">
            <.button
              type="button"
              size="sm"
              phx-click={@on_close}
              phx-target={@target}
              class="pf-action-button"
            >
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
          </div>
        </div>

        <%!-- Add Sub-Dialog --%>
        <.add_sub_form :if={@show_add_dialog} target={@target} scope={@sub_scope} />
        <%!-- Edit Sub-Dialog --%>
        <.edit_sub_form
          :if={@show_edit_dialog}
          target={@target}
          entries={@entries}
          selected={@selected}
          scope={@sub_scope}
        />
      </.focus_wrap>
    </div>
    """
  end

  # ── Sub-Forms ─────────────────────────────────────────

  attr :target, :any, default: nil

  attr :scope, :atom, default: :window

  defp add_sub_form(assigns) do
    ~H"""
    <.dialog
      id="perform-add-modal"
      show
      scope={@scope}
      on_cancel={JS.push("close_perform_add", target: @target)}
      class="md:max-w-sm"
    >
      <.dialog_header
        id="perform-add-modal"
        title={dgettext("dialogs", "Add Perform Command")}
        on_close={JS.push("close_perform_add", target: @target)}
      >
        <:icon><Icons.icon_dialog_perform /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form
          phx-submit="perform_add_confirm"
          phx-target={@target}
          data-testid="perform-add-dialog"
          class="pf-sub-form"
        >
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="perform-command-input">
              {dgettext("dialogs", "Command")}:
            </label>
            <.textarea
              id="perform-command-input"
              name="command"
              maxlength="500"
              placeholder={dgettext("dialogs", "/join #channel")}
              required
              autofocus
              rows="3"
              class="pf-command-input w-full resize-none"
            />
          </div>
          <div class="pf-form-actions flex justify-end gap-1">
            <.button type="submit" size="sm" class="pf-action-button">
              <:icon><Icons.icon_checkmark /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click="close_perform_add"
              phx-target={@target}
              class="pf-action-button"
            >
              <:icon><Icons.icon_close /></:icon>
              {dgettext("dialogs", "Cancel")}
            </.button>
          </div>
        </form>
      </.dialog_body>
    </.dialog>
    """
  end

  attr :target, :any, default: nil
  attr :entries, :list, required: true
  attr :selected, :integer, default: nil

  attr :scope, :atom, default: :window

  defp edit_sub_form(assigns) do
    entry = Enum.find(assigns.entries, fn e -> e.position == assigns.selected end)
    assigns = assign(assigns, :edit_command, if(entry, do: entry.command, else: ""))

    ~H"""
    <.dialog
      id="perform-edit-modal"
      show
      scope={@scope}
      on_cancel={JS.push("close_perform_edit", target: @target)}
      class="md:max-w-sm"
    >
      <.dialog_header
        id="perform-edit-modal"
        title={dgettext("dialogs", "Edit Perform Command")}
        on_close={JS.push("close_perform_edit", target: @target)}
      >
        <:icon><Icons.icon_dialog_perform /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form
          phx-submit="perform_edit_confirm"
          phx-target={@target}
          data-testid="perform-edit-dialog"
          class="pf-sub-form"
        >
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="perform-edit-input">
              {dgettext("dialogs", "Command")}:
            </label>
            <.textarea
              id="perform-edit-input"
              name="command"
              maxlength="500"
              value={@edit_command}
              required
              autofocus
              rows="3"
              class="pf-command-input w-full resize-none"
            />
          </div>
          <div class="pf-form-actions flex justify-end gap-1">
            <.button type="submit" size="sm" class="pf-action-button">
              <:icon><Icons.icon_checkmark /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click="close_perform_edit"
              phx-target={@target}
              class="pf-action-button"
            >
              <:icon><Icons.icon_close /></:icon>
              {dgettext("dialogs", "Cancel")}
            </.button>
          </div>
        </form>
      </.dialog_body>
    </.dialog>
    """
  end

  # ── Private Helpers ───────────────────────────────────

  @spec mask_command(String.t()) :: String.t()
  defp mask_command(cmd) do
    cmd
    |> String.replace(~r{(?i)(identify|ns identify|nickserv identify)\s+\S+}, "\\1 ***")
    |> String.replace(~r{(?i)(msg\s+nickserv\s+identify)\s+\S+}, "\\1 ***")
  end

  @spec row_class(boolean()) :: String.t()
  defp row_class(true), do: "pf-entry bg-selection-bg text-selection-fg"
  defp row_class(false), do: "pf-entry"
end
