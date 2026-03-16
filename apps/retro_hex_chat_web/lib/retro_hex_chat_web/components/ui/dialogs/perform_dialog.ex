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
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.Separator
  import RetroHexChatWeb.Components.UI.Input

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
  attr :show, :boolean, default: false
  attr :active_tab, :string, default: "commands"
  attr :perform_entries, :list, default: []
  attr :perform_selected, :integer, default: nil
  attr :perform_enabled, :boolean, default: true
  attr :autojoin_entries, :list, default: []
  attr :autojoin_selected, :string, default: nil
  attr :on_tab, :any, default: nil
  attr :on_select, :any, default: nil
  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_remove, :any, default: nil
  attr :on_move_up, :any, default: nil
  attr :on_move_down, :any, default: nil
  attr :on_toggle_enabled, :any, default: nil
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
    >
      <.dialog_header id={@id} title="Perform">
        <:icon><Icons.icon_dialog_perform /></:icon>
      </.dialog_header>
      <.dialog_body>
        <.tabs :let={builder} id={"#{@id}-tabs"} default={@active_tab}>
          <.tabs_list>
            <.tabs_trigger builder={builder} value="commands">
              <:icon><Icons.icon_tab_commands class="w-4 h-4" /></:icon>
              Commands
            </.tabs_trigger>
            <.tabs_trigger builder={builder} value="autojoin">
              <:icon><Icons.icon_tab_autojoin class="w-4 h-4" /></:icon>
              Auto-Join
            </.tabs_trigger>
          </.tabs_list>

          <.tabs_content value="commands">
            <.commands_tab
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

          <.tabs_content value="autojoin">
            <.autojoin_tab
              entries={@autojoin_entries}
              selected={@autojoin_selected}
              on_select={@on_select}
              on_add={@on_add}
              on_edit={@on_edit}
              on_remove={@on_remove}
            />
          </.tabs_content>
        </.tabs>
      </.dialog_body>
      <.dialog_footer>
        <.button phx-click={@on_ok}>
          <:icon><Icons.icon_checkmark /></:icon>
          OK
        </.button>
        <.button variant="outline" phx-click={@on_cancel || hide_modal(@id)}>
          <:icon><Icons.icon_close /></:icon>
          Cancel
        </.button>
      </.dialog_footer>
    </.dialog>

    <%!-- Perform Add Sub-Dialog --%>
    <.perform_add_sub_form :if={@show_perform_add_dialog} />
    <%!-- Perform Edit Sub-Dialog --%>
    <.perform_edit_sub_form
      :if={@show_perform_edit_dialog}
      entries={@perform_entries}
      selected={@perform_selected}
    />
    <%!-- Autojoin Add Sub-Dialog --%>
    <.autojoin_add_sub_form :if={@show_autojoin_add_dialog} />
    <%!-- Autojoin Edit Sub-Dialog --%>
    <.autojoin_edit_sub_form
      :if={@show_autojoin_edit_dialog}
      entries={@autojoin_entries}
      selected={@autojoin_selected}
    />
    """
  end

  # ── Sub-Forms ─────────────────────────────────────────

  defp perform_add_sub_form(assigns) do
    ~H"""
    <div class="fixed inset-0 z-modal-above bg-black/50 flex items-center justify-center">
      <div class="bg-surface shadow-retro-window p-[3px] w-full max-w-sm">
        <div class="bg-title-bar flex items-center gap-retro-4 px-retro-2 py-retro-2">
          <span class="text-xs font-bold text-white truncate select-none">Add Perform Command</span>
          <div class="ml-auto">
            <button type="button" aria-label="Close" phx-click="close_perform_add_dialog" />
          </div>
        </div>
        <div class="p-2">
          <form phx-submit="perform_dialog_add_confirm" data-testid="perform-add-dialog">
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="perform-command-input">Command:</label>
              <.input
                type="text"
                id="perform-command-input"
                name="command"
                maxlength="500"
                placeholder="/join #channel"
                required
                autofocus
                class="w-full"
              />
            </div>
            <div class="flex justify-end gap-1">
              <.button type="submit" size="sm">
                <:icon><Icons.icon_checkmark /></:icon>
                OK
              </.button>
              <.button
                type="button"
                size="sm"
                variant="outline"
                phx-click="close_perform_add_dialog"
              >
                <:icon><Icons.icon_close /></:icon>
                Cancel
              </.button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  attr :entries, :list, required: true
  attr :selected, :integer, default: nil

  defp perform_edit_sub_form(assigns) do
    entry = Enum.find(assigns.entries, fn e -> e.position == assigns.selected end)
    assigns = assign(assigns, :edit_command, if(entry, do: entry.command, else: ""))

    ~H"""
    <div class="fixed inset-0 z-modal-above bg-black/50 flex items-center justify-center">
      <div class="bg-surface shadow-retro-window p-[3px] w-full max-w-sm">
        <div class="bg-title-bar flex items-center gap-retro-4 px-retro-2 py-retro-2">
          <span class="text-xs font-bold text-white truncate select-none">Edit Perform Command</span>
          <div class="ml-auto">
            <button type="button" aria-label="Close" phx-click="close_perform_edit_dialog" />
          </div>
        </div>
        <div class="p-2">
          <form phx-submit="perform_dialog_edit_confirm" data-testid="perform-edit-dialog">
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="perform-edit-input">Command:</label>
              <.input
                type="text"
                id="perform-edit-input"
                name="command"
                maxlength="500"
                value={@edit_command}
                required
                autofocus
                class="w-full"
              />
            </div>
            <div class="flex justify-end gap-1">
              <.button type="submit" size="sm">
                <:icon><Icons.icon_checkmark /></:icon>
                OK
              </.button>
              <.button
                type="button"
                size="sm"
                variant="outline"
                phx-click="close_perform_edit_dialog"
              >
                <:icon><Icons.icon_close /></:icon>
                Cancel
              </.button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp autojoin_add_sub_form(assigns) do
    ~H"""
    <div class="fixed inset-0 z-modal-above bg-black/50 flex items-center justify-center">
      <div class="bg-surface shadow-retro-window p-[3px] w-full max-w-xs">
        <div class="bg-title-bar flex items-center gap-retro-4 px-retro-2 py-retro-2">
          <span class="text-xs font-bold text-white truncate select-none">Add Auto-Join Channel</span>
          <div class="ml-auto">
            <button type="button" aria-label="Close" phx-click="close_autojoin_add_dialog" />
          </div>
        </div>
        <div class="p-2">
          <form phx-submit="autojoin_dialog_add_confirm" data-testid="autojoin-add-dialog">
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="autojoin-channel-input">Channel:</label>
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
              <label class="text-xs font-bold" for="autojoin-key-input">Key:</label>
              <.input
                type="text"
                id="autojoin-key-input"
                name="key"
                maxlength="50"
                placeholder="Leave empty if no key"
                class="w-full"
              />
            </div>
            <div class="flex justify-end gap-1">
              <.button type="submit" size="sm">
                <:icon><Icons.icon_checkmark /></:icon>
                OK
              </.button>
              <.button
                type="button"
                size="sm"
                variant="outline"
                phx-click="close_autojoin_add_dialog"
              >
                <:icon><Icons.icon_close /></:icon>
                Cancel
              </.button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  attr :entries, :list, required: true
  attr :selected, :string, default: nil

  defp autojoin_edit_sub_form(assigns) do
    entry = Enum.find(assigns.entries, fn e -> e.channel_name == assigns.selected end)

    assigns =
      assign(assigns,
        edit_channel: if(entry, do: entry.channel_name, else: ""),
        edit_key: if(entry, do: entry.channel_key, else: "")
      )

    ~H"""
    <div class="fixed inset-0 z-modal-above bg-black/50 flex items-center justify-center">
      <div class="bg-surface shadow-retro-window p-[3px] w-full max-w-xs">
        <div class="bg-title-bar flex items-center gap-retro-4 px-retro-2 py-retro-2">
          <span class="text-xs font-bold text-white truncate select-none">
            Edit Auto-Join Channel
          </span>
          <div class="ml-auto">
            <button type="button" aria-label="Close" phx-click="close_autojoin_edit_dialog" />
          </div>
        </div>
        <div class="p-2">
          <form phx-submit="autojoin_dialog_edit_confirm" data-testid="autojoin-edit-dialog">
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="autojoin-edit-channel">Channel:</label>
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
              <label class="text-xs font-bold" for="autojoin-edit-key">Key:</label>
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
            <div class="flex justify-end gap-1">
              <.button type="submit" size="sm">
                <:icon><Icons.icon_checkmark /></:icon>
                OK
              </.button>
              <.button
                type="button"
                size="sm"
                variant="outline"
                phx-click="close_autojoin_edit_dialog"
              >
                <:icon><Icons.icon_close /></:icon>
                Cancel
              </.button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  # ── Commands Tab ──────────────────────────────────────

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
    <div class="overflow-y-auto max-h-[200px] shadow-retro-field bg-white mb-2">
      <.table>
        <.table_header>
          <.table_row>
            <.table_head class="w-[60px] text-xs px-2 py-1">#</.table_head>
            <.table_head class="text-xs px-2 py-1">Command</.table_head>
          </.table_row>
        </.table_header>
        <.table_body>
          <.table_row
            :for={entry <- @entries}
            class={
              classes([
                "cursor-pointer text-xs",
                @selected == entry.position && "bg-primary text-white"
              ])
            }
            phx-click={@on_select}
            phx-value-position={entry.position}
          >
            <.table_cell class="px-2 py-1 text-xs">{entry.position}</.table_cell>
            <.table_cell class="px-2 py-1 text-xs font-mono">
              {mask_command(entry.command)}
            </.table_cell>
          </.table_row>
          <tr :if={@entries == []}>
            <td colspan="2" class="px-2 py-4 text-xs text-center text-muted-foreground">
              No commands configured. Click Add to create one.
            </td>
          </tr>
        </.table_body>
      </.table>
    </div>

    <div class="flex gap-1 mb-2">
      <.button size="sm" phx-click={@on_add}>
        <:icon><Icons.icon_btn_add /></:icon>
        Add
      </.button>
      <.button size="sm" phx-click={@on_edit} disabled={!@has_selection}>
        <:icon><Icons.icon_btn_edit /></:icon>
        Edit
      </.button>
      <.button size="sm" variant="destructive" phx-click={@on_remove} disabled={!@has_selection}>
        <:icon><Icons.icon_btn_remove /></:icon>
        Remove
      </.button>
      <.button
        size="sm"
        variant="outline"
        phx-click={@on_move_up}
        disabled={!@has_selection || @selected == @first_pos}
      >
        <:icon><Icons.icon_btn_up /></:icon>
        Up
      </.button>
      <.button
        size="sm"
        variant="outline"
        phx-click={@on_move_down}
        disabled={!@has_selection || @selected == @last_pos}
      >
        <:icon><Icons.icon_btn_down /></:icon>
        Down
      </.button>
    </div>

    <.separator class="my-2" />

    <label class="inline-flex items-center gap-2 text-xs cursor-pointer">
      <.checkbox
        name="perform_enabled"
        value={@enabled}
        phx-click={@on_toggle_enabled}
      /> Enable perform on connect
    </label>
    """
  end

  # ── Auto-Join Tab ─────────────────────────────────────

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
    <div class="overflow-y-auto max-h-[200px] shadow-retro-field bg-white mb-2">
      <.table>
        <.table_header>
          <.table_row>
            <.table_head class="text-xs px-2 py-1">Channel</.table_head>
            <.table_head class="w-[80px] text-xs px-2 py-1">Key</.table_head>
          </.table_row>
        </.table_header>
        <.table_body>
          <.table_row
            :for={entry <- @entries}
            class={
              classes([
                "cursor-pointer text-xs",
                @selected == entry.channel_name && "bg-primary text-white"
              ])
            }
            phx-click={@on_select}
            phx-value-channel={entry.channel_name}
          >
            <.table_cell class="px-2 py-1 text-xs">{entry.channel_name}</.table_cell>
            <.table_cell class="px-2 py-1 text-xs">
              {if entry.channel_key, do: "***", else: ""}
            </.table_cell>
          </.table_row>
          <tr :if={@entries == []}>
            <td colspan="2" class="px-2 py-4 text-xs text-center text-muted-foreground">
              No auto-join channels. Click Add to create one.
            </td>
          </tr>
        </.table_body>
      </.table>
    </div>

    <div class="flex gap-1">
      <.button size="sm" phx-click={@on_add}>
        <:icon><Icons.icon_btn_add /></:icon>
        Add
      </.button>
      <.button size="sm" phx-click={@on_edit} disabled={!@has_selection}>
        <:icon><Icons.icon_btn_edit /></:icon>
        Edit
      </.button>
      <.button size="sm" variant="destructive" phx-click={@on_remove} disabled={!@has_selection}>
        <:icon><Icons.icon_btn_remove /></:icon>
        Remove
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
end
