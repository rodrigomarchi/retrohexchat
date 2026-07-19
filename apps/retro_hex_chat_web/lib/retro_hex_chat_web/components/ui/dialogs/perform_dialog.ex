defmodule RetroHexChatWeb.Components.UI.PerformDialog do
  @moduledoc """
  Win98-style Perform dialog component for the showcase design system.

  Provides a tabbed dialog for managing auto-execute commands (perform on connect)
  and auto-join channels. Commands tab supports reordering; both tabs support
  add/edit/remove operations.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Tabs
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.Separator
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Textarea

  alias RetroHexChatWeb.Icons

  @doc """
  Renders a Win98-style Perform dialog with Commands and Auto-Join tabs.

  ## Examples

      <.perform_dialog
        id="perform"
        show={true}
        perform_entries={[%{position: 1, command: "/join #lobby"}]}
        autojoin_entries={[%{channel_name: "#lobby", channel_key: nil}]}
      />
  """
  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :show, :boolean, default: false
  attr :active_tab, :string, default: "commands"
  attr :perform_entries, :list, default: []
  attr :perform_selected, :integer, default: nil
  attr :perform_enabled, :boolean, default: true
  attr :autojoin_entries, :list, default: []
  attr :autojoin_selected, :string, default: nil
  attr :on_select, :any, default: nil
  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_remove, :any, default: nil
  attr :on_move_up, :any, default: nil
  attr :on_move_down, :any, default: nil
  attr :on_toggle_enabled, :any, default: nil
  attr :on_autojoin_select, :any, default: nil
  attr :on_autojoin_add, :any, default: nil
  attr :on_autojoin_edit, :any, default: nil
  attr :on_autojoin_remove, :any, default: nil
  attr :show_perform_add_dialog, :boolean, default: false
  attr :show_perform_edit_dialog, :boolean, default: false
  attr :show_autojoin_add_dialog, :boolean, default: false
  attr :show_autojoin_edit_dialog, :boolean, default: false
  attr :on_ok, :any, default: nil
  attr :on_cancel, :any, default: nil

  @spec perform_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def perform_dialog(assigns) do
    ~H"""
    <.dialog
      id={@id}
      show={@show}
      lock={
        @show_perform_add_dialog || @show_perform_edit_dialog ||
          @show_autojoin_add_dialog || @show_autojoin_edit_dialog
      }
      on_cancel={@on_cancel}
    >
      <.dialog_header id={@id} title={dgettext("dialogs", "Perform")} on_close={@on_cancel}>
        <:icon><Icons.icon_dialog_perform /></:icon>
      </.dialog_header>
      <.dialog_body>
        <.perform_panel
          id={@id}
          target={@target}
          active_tab={@active_tab}
          perform_entries={@perform_entries}
          perform_selected={@perform_selected}
          perform_enabled={@perform_enabled}
          autojoin_entries={@autojoin_entries}
          autojoin_selected={@autojoin_selected}
          show_perform_add_dialog={@show_perform_add_dialog}
          show_perform_edit_dialog={@show_perform_edit_dialog}
          show_autojoin_add_dialog={@show_autojoin_add_dialog}
          show_autojoin_edit_dialog={@show_autojoin_edit_dialog}
          on_select={@on_select}
          on_add={@on_add}
          on_edit={@on_edit}
          on_remove={@on_remove}
          on_move_up={@on_move_up}
          on_move_down={@on_move_down}
          on_toggle_enabled={@on_toggle_enabled}
          on_autojoin_select={@on_autojoin_select}
          on_autojoin_add={@on_autojoin_add}
          on_autojoin_edit={@on_autojoin_edit}
          on_autojoin_remove={@on_autojoin_remove}
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
  Renders the Perform content (Commands/Auto-Join tabs + the four add/edit
  sub-form modals) without any frame — compose it inside a dialog or a desktop
  window body. `sub_scope` decides where the sub-form modals anchor.
  """
  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :active_tab, :string, default: "commands"
  attr :perform_entries, :list, default: []
  attr :perform_selected, :integer, default: nil
  attr :perform_enabled, :boolean, default: true
  attr :autojoin_entries, :list, default: []
  attr :autojoin_selected, :string, default: nil
  attr :show_perform_add_dialog, :boolean, default: false
  attr :show_perform_edit_dialog, :boolean, default: false
  attr :show_autojoin_add_dialog, :boolean, default: false
  attr :show_autojoin_edit_dialog, :boolean, default: false
  attr :on_select, :any, default: nil
  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_remove, :any, default: nil
  attr :on_move_up, :any, default: nil
  attr :on_move_down, :any, default: nil
  attr :on_toggle_enabled, :any, default: nil
  attr :on_autojoin_select, :any, default: nil
  attr :on_autojoin_add, :any, default: nil
  attr :on_autojoin_edit, :any, default: nil
  attr :on_autojoin_remove, :any, default: nil
  attr :on_close, :any, default: nil
  attr :sub_scope, :atom, default: :window, values: [:viewport, :window]

  @spec perform_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def perform_panel(assigns) do
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
          <.tabs :let={builder} id={"#{@id}-tabs"} default={@active_tab} class="pf-tabs min-h-0">
            <div class="pf-tabs-shell">
              <.tabs_list class="pf-main-tabs">
                <.tabs_trigger builder={builder} value="commands">
                  <:icon><Icons.icon_tab_commands class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Commands")}
                </.tabs_trigger>
                <.tabs_trigger builder={builder} value="autojoin">
                  <:icon><Icons.icon_tab_autojoin class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Auto-Join")}
                </.tabs_trigger>
              </.tabs_list>
            </div>

            <.tabs_content value="commands" class="pf-tab-content">
              <.commands_tab
                target={@target}
                entries={@perform_entries}
                selected={@perform_selected}
                enabled={@perform_enabled}
                on_select={@on_select}
                on_add={@on_add}
                on_edit={@on_edit}
                on_remove={@on_remove}
                on_move_up={@on_move_up}
                on_move_down={@on_move_down}
                on_toggle_enabled={@on_toggle_enabled}
              />
            </.tabs_content>

            <.tabs_content value="autojoin" class="pf-tab-content">
              <.autojoin_tab
                target={@target}
                entries={@autojoin_entries}
                selected={@autojoin_selected}
                on_select={@on_autojoin_select}
                on_add={@on_autojoin_add}
                on_edit={@on_autojoin_edit}
                on_remove={@on_autojoin_remove}
              />
            </.tabs_content>
          </.tabs>

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

        <%!-- Perform Add Sub-Dialog --%>
        <.perform_add_sub_form :if={@show_perform_add_dialog} target={@target} scope={@sub_scope} />
        <%!-- Perform Edit Sub-Dialog --%>
        <.perform_edit_sub_form
          :if={@show_perform_edit_dialog}
          target={@target}
          entries={@perform_entries}
          selected={@perform_selected}
          scope={@sub_scope}
        />
        <%!-- Autojoin Add Sub-Dialog --%>
        <.autojoin_add_sub_form :if={@show_autojoin_add_dialog} target={@target} scope={@sub_scope} />
        <%!-- Autojoin Edit Sub-Dialog --%>
        <.autojoin_edit_sub_form
          :if={@show_autojoin_edit_dialog}
          target={@target}
          entries={@autojoin_entries}
          selected={@autojoin_selected}
          scope={@sub_scope}
        />
      </.focus_wrap>
    </div>
    """
  end

  # ── Sub-Forms ─────────────────────────────────────────

  attr :target, :any, default: nil

  attr :scope, :atom, default: :window

  defp perform_add_sub_form(assigns) do
    ~H"""
    <.dialog
      id="perform-add-modal"
      show
      scope={@scope}
      on_cancel={JS.push("close_perform_add_dialog", target: @target)}
      class="md:max-w-sm"
    >
      <.dialog_header
        id="perform-add-modal"
        title={dgettext("dialogs", "Add Perform Command")}
        on_close={JS.push("close_perform_add_dialog", target: @target)}
      >
        <:icon><Icons.icon_dialog_perform /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form
          phx-submit="perform_dialog_add_confirm"
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
              phx-click="close_perform_add_dialog"
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

  defp perform_edit_sub_form(assigns) do
    entry = Enum.find(assigns.entries, fn e -> e.position == assigns.selected end)
    assigns = assign(assigns, :edit_command, if(entry, do: entry.command, else: ""))

    ~H"""
    <.dialog
      id="perform-edit-modal"
      show
      scope={@scope}
      on_cancel={JS.push("close_perform_edit_dialog", target: @target)}
      class="md:max-w-sm"
    >
      <.dialog_header
        id="perform-edit-modal"
        title={dgettext("dialogs", "Edit Perform Command")}
        on_close={JS.push("close_perform_edit_dialog", target: @target)}
      >
        <:icon><Icons.icon_dialog_perform /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form
          phx-submit="perform_dialog_edit_confirm"
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
              phx-click="close_perform_edit_dialog"
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

  attr :scope, :atom, default: :window

  defp autojoin_add_sub_form(assigns) do
    ~H"""
    <.dialog
      id="autojoin-add-modal"
      show
      scope={@scope}
      on_cancel={JS.push("close_autojoin_add_dialog", target: @target)}
      class="md:max-w-xs"
    >
      <.dialog_header
        id="autojoin-add-modal"
        title={dgettext("dialogs", "Add Auto-Join Channel")}
        on_close={JS.push("close_autojoin_add_dialog", target: @target)}
      >
        <:icon><Icons.icon_dialog_perform /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form
          phx-submit="autojoin_dialog_add_confirm"
          phx-target={@target}
          data-testid="autojoin-add-dialog"
          class="pf-sub-form"
        >
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="autojoin-channel-input">
              {dgettext("dialogs", "Channel")}:
            </label>
            <.input
              type="text"
              id="autojoin-channel-input"
              name="channel"
              maxlength="50"
              placeholder="#channel"
              required
              autofocus
              class="w-full"
            />
          </div>
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="autojoin-key-input">
              {dgettext("dialogs", "Key")}:
            </label>
            <.input
              type="text"
              id="autojoin-key-input"
              name="key"
              maxlength="50"
              placeholder={dgettext("dialogs", "Leave empty if no key")}
              class="w-full"
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
              phx-click="close_autojoin_add_dialog"
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
  attr :selected, :string, default: nil

  attr :scope, :atom, default: :window

  defp autojoin_edit_sub_form(assigns) do
    entry = Enum.find(assigns.entries, fn e -> e.channel_name == assigns.selected end)

    assigns =
      assign(assigns,
        edit_channel: if(entry, do: entry.channel_name, else: ""),
        edit_key: if(entry, do: entry.channel_key, else: "")
      )

    ~H"""
    <.dialog
      id="autojoin-edit-modal"
      show
      scope={@scope}
      on_cancel={JS.push("close_autojoin_edit_dialog", target: @target)}
      class="md:max-w-xs"
    >
      <.dialog_header
        id="autojoin-edit-modal"
        title={dgettext("dialogs", "Edit Auto-Join Channel")}
        on_close={JS.push("close_autojoin_edit_dialog", target: @target)}
      >
        <:icon><Icons.icon_dialog_perform /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form
          phx-submit="autojoin_dialog_edit_confirm"
          phx-target={@target}
          data-testid="autojoin-edit-dialog"
          class="pf-sub-form"
        >
          <input type="hidden" name="channel" value={@edit_channel} />
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="autojoin-edit-channel">
              {dgettext("dialogs", "Channel")}:
            </label>
            <.input
              type="text"
              id="autojoin-edit-channel"
              name="channel"
              value={@edit_channel}
              disabled
              class="w-full"
            />
          </div>
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="autojoin-edit-key">
              {dgettext("dialogs", "Key")}:
            </label>
            <.input
              type="text"
              id="autojoin-edit-key"
              name="key"
              maxlength="50"
              value={@edit_key}
              autofocus
              class="w-full"
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
              phx-click="close_autojoin_edit_dialog"
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

  # ── Commands Tab ──────────────────────────────────────

  attr :target, :any, default: nil
  attr :entries, :list, required: true
  attr :selected, :integer, default: nil
  attr :enabled, :boolean, default: true
  attr :on_select, :any, default: nil
  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_remove, :any, default: nil
  attr :on_move_up, :any, default: nil
  attr :on_move_down, :any, default: nil
  attr :on_toggle_enabled, :any, default: nil

  defp commands_tab(assigns) do
    first_pos = if assigns.entries != [], do: List.first(assigns.entries).position, else: nil
    last_pos = if assigns.entries != [], do: List.last(assigns.entries).position, else: nil
    has_selection = assigns.selected != nil

    assigns =
      assign(assigns,
        first_pos: first_pos,
        last_pos: last_pos,
        has_selection: has_selection
      )

    ~H"""
    <div class="pf-entry-list overflow-y-auto max-h-[220px] mb-2">
      <div :if={@entries == []} class="pf-empty-state text-center text-muted-foreground">
        {dgettext("dialogs", "No commands configured. Click Add to create one.")}
      </div>

      <button
        :for={entry <- @entries}
        type="button"
        data-testid="perform-command-row"
        data-position={entry.position}
        aria-pressed={@selected == entry.position}
        class={row_class("pf-entry", @selected == entry.position)}
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

    <div class="pf-action-row flex gap-1 mb-2">
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
    """
  end

  # ── Auto-Join Tab ─────────────────────────────────────

  attr :target, :any, default: nil
  attr :entries, :list, required: true
  attr :selected, :string, default: nil
  attr :on_select, :any, default: nil
  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_remove, :any, default: nil

  defp autojoin_tab(assigns) do
    has_selection = assigns.selected != nil
    assigns = assign(assigns, :has_selection, has_selection)

    ~H"""
    <div class="pf-entry-list overflow-y-auto max-h-[220px] mb-2">
      <div :if={@entries == []} class="pf-empty-state text-center text-muted-foreground">
        {dgettext("dialogs", "No auto-join channels. Click Add to create one.")}
      </div>

      <button
        :for={entry <- @entries}
        type="button"
        data-testid="autojoin-row"
        data-channel={entry.channel_name}
        aria-pressed={@selected == entry.channel_name}
        class={row_class("pf-entry pf-autojoin-entry", @selected == entry.channel_name)}
        phx-click={@on_select}
        phx-target={@target}
        phx-value-channel={entry.channel_name}
      >
        <span class="pf-entry-content">
          <span class="pf-entry-label">{entry.channel_name}</span>
          <span class="pf-entry-meta">
            {dgettext("dialogs", "Key")}: {if entry.channel_key,
              do: "***",
              else: dgettext("dialogs", "none")}
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
    </div>
    """
  end

  # ── Private Helpers ───────────────────────────────────

  @spec mask_command(String.t()) :: String.t()
  defp mask_command(cmd) do
    cmd
    |> String.replace(~r{(?i)(identify|ns identify|nickserv identify)\s+\S+}, "\\1 ***")
    |> String.replace(~r{(?i)(msg\s+nickserv\s+identify)\s+\S+}, "\\1 ***")
  end

  defp row_class(base, true), do: "#{base} bg-selection-bg text-selection-fg"
  defp row_class(base, false), do: base
end
