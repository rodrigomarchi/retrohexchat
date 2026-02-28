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
  attr :on_ok, :any, default: nil
  attr :on_cancel, :any, default: nil

  @spec perform_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def perform_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show}>
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
