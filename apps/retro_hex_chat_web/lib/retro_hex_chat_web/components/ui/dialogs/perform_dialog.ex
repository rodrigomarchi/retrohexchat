defmodule RetroHexChatWeb.Components.UI.PerformDialog do
  @moduledoc """
  Win98-style Perform dialog component for the showcase design system.

  Manages the commands executed automatically on connect: add, edit, remove,
  reorder, and the master enable toggle.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.ActionList
  import RetroHexChatWeb.Components.UI.DialogBanner
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.Separator
  import RetroHexChatWeb.Components.UI.Textarea

  alias RetroHexChatWeb.Components.Diagrams
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
  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_remove, :any, default: nil
  attr :on_move_up, :any, default: nil
  attr :on_move_down, :any, default: nil
  attr :on_toggle_enabled, :any, default: nil
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
          on_add={@on_add}
          on_edit={@on_edit}
          on_remove={@on_remove}
          on_move_up={@on_move_up}
          on_move_down={@on_move_down}
          on_toggle_enabled={@on_toggle_enabled}
          sub_scope={:viewport}
        />
      </.dialog_body>
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
  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_remove, :any, default: nil
  attr :on_move_up, :any, default: nil
  attr :on_move_down, :any, default: nil
  attr :on_toggle_enabled, :any, default: nil
  attr :sub_scope, :atom, default: :window, values: [:viewport, :window]

  @spec perform_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def perform_panel(assigns) do
    assigns = assign(assigns, :perform_lines, perform_lines(assigns.entries, assigns.enabled))

    first_pos = if assigns.entries != [], do: List.first(assigns.entries).position, else: nil
    last_pos = if assigns.entries != [], do: List.last(assigns.entries).position, else: nil

    assigns =
      assign(assigns, first_pos: first_pos, last_pos: last_pos)

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
          <.dialog_banner heading={dgettext("dialogs", "What runs the moment you connect")}>
            <:art>
              <Diagrams.diagram_dialog_preview
                title={dgettext("dialogs", "Status")}
                kind={:ordered}
                lines={@perform_lines}
                label={dgettext("dialogs", "A miniature of the commands that run on connect")}
              />
            </:art>
            <:glyph><Icons.icon_dialog_perform class="h-8 w-8" /></:glyph>
            {dgettext(
              "dialogs",
              "Every line here is sent as if you had typed it, top to bottom, once the connection is up. Turning the list off keeps the lines and runs none of them."
            )}
          </.dialog_banner>

          <div class="pf-entry-list min-h-0 flex-1 overflow-y-auto">
            <div :if={@entries == []} class="pf-empty-state text-center text-muted-foreground">
              {dgettext("dialogs", "No commands configured. Click Add to create one.")}
            </div>

            <.action_list
              :if={@entries != []}
              id={"#{@id}-commands"}
              label={dgettext("dialogs", "Perform")}
            >
              <.action_row
                :for={entry <- @entries}
                on_activate={@on_edit}
                value={%{"position" => entry.position}}
                target={@target}
                current={@selected == entry.position}
                data-testid="perform-command-row"
                data-position={entry.position}
              >
                <:icon><span class="pf-entry-index">{entry.position}</span></:icon>
                <:title>{mask_command(entry.command)}</:title>
                <:action
                  event={@on_move_up}
                  value={%{"position" => entry.position}}
                  label={dgettext("dialogs", "Move %{name} up", name: mask_command(entry.command))}
                  target={@target}
                  disabled={entry.position == @first_pos}
                  testid={"perform-move-up-#{entry.position}"}
                >
                  <Icons.icon_btn_up class="w-4 h-4" />
                </:action>
                <:action
                  event={@on_move_down}
                  value={%{"position" => entry.position}}
                  label={dgettext("dialogs", "Move %{name} down", name: mask_command(entry.command))}
                  target={@target}
                  disabled={entry.position == @last_pos}
                  testid={"perform-move-down-#{entry.position}"}
                >
                  <Icons.icon_btn_down class="w-4 h-4" />
                </:action>
                <:action
                  event={@on_remove}
                  value={%{"position" => entry.position}}
                  label={dgettext("dialogs", "Remove %{name}", name: mask_command(entry.command))}
                  variant="destructive"
                  target={@target}
                  testid={"perform-remove-#{entry.position}"}
                >
                  <Icons.icon_btn_remove class="w-4 h-4" />
                </:action>
              </.action_row>
            </.action_list>
          </div>

          <div class="pf-action-row flex gap-1">
            <.button size="sm" phx-click={@on_add} phx-target={@target} class="pf-action-button">
              <:icon><Icons.icon_btn_add /></:icon>
              {dgettext("dialogs", "Add")}
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

  # Switched off, the list still exists and nothing in it runs — so the
  # picture shows the Status window as it will actually look: empty.
  @spec perform_lines([map()], boolean()) :: [map()]
  defp perform_lines(_entries, false), do: []

  defp perform_lines(entries, true) do
    # The same masking the list applies: a perform line often carries the
    # NickServ password, and a picture of it is no less a leak than a row.
    Enum.map(entries, &%{text: mask_command(&1.command), tone: :muted})
  end
end
