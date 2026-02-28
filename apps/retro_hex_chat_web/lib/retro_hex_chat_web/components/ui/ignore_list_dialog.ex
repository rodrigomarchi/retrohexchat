defmodule RetroHexChatWeb.Components.UI.IgnoreListDialog do
  @moduledoc """
  Ignore list management dialog for the showcase design system.

  Composed from dialog + table + button + input primitives.
  Shows ignored users with nickname, reason, and expiry. Add/Remove actions.

  ## Usage

      <.ignore_list_dialog
        id="ignore-list"
        show={true}
        entries={[
          %{nickname: "BadUser", reason: "Spam", expires_at: nil},
          %{nickname: "FloodBot", reason: "Flood", expires_at: "2026-03-01"}
        ]}
        on_add="ignore_add"
        on_remove="ignore_remove"
        on_close="close_ignore_dialog"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders the ignore list management dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :entries, :list,
    default: [],
    doc: "List of ignore entry maps with :nickname, :reason, and :expires_at keys"

  attr :selected, :string, default: nil, doc: "Nickname of the currently selected entry"
  attr :on_select, :any, default: nil, doc: "Row click callback (receives phx-value-nickname)"
  attr :on_add, :any, default: nil, doc: "Add button callback"
  attr :on_remove, :any, default: nil, doc: "Remove button callback"
  attr :on_close, :any, default: nil, doc: "Close button callback"

  @spec ignore_list_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def ignore_list_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header>
        <.dialog_icon>
          <Icons.icon_dialog_ignore class="w-4 h-4" />
        </.dialog_icon>
        <.dialog_title>Ignore List</.dialog_title>
        <.dialog_close id={@id} />
      </.dialog_header>

      <.dialog_body>
        <div class="space-y-retro-8">
          <%!-- Ignore entries table --%>
          <div class="max-h-[220px] overflow-y-auto retro-scrollbar shadow-retro-sunken">
            <.table>
              <.table_header>
                <.table_row>
                  <.table_head>Nickname</.table_head>
                  <.table_head>Reason</.table_head>
                  <.table_head>Expires</.table_head>
                </.table_row>
              </.table_header>
              <.table_body>
                <tr :if={@entries == []}>
                  <td colspan="3" class="p-4 text-center text-muted-foreground text-xs">
                    No users ignored.
                  </td>
                </tr>
                <.table_row
                  :for={entry <- @entries}
                  class={
                    if(entry.nickname == @selected,
                      do: "bg-selection-bg text-selection-fg cursor-pointer",
                      else: "cursor-pointer"
                    )
                  }
                  phx-click={@on_select}
                  phx-value-nickname={entry.nickname}
                >
                  <.table_cell class="font-bold text-xs">{entry.nickname}</.table_cell>
                  <.table_cell class="text-xs">{entry.reason || "—"}</.table_cell>
                  <.table_cell class="text-xs">{format_expires(entry.expires_at)}</.table_cell>
                </.table_row>
              </.table_body>
            </.table>
          </div>

          <%!-- Action buttons --%>
          <div class="flex gap-retro-4">
            <.button size="sm" variant="outline" phx-click={@on_add}>
              <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
              Add...
            </.button>
            <.button
              size="sm"
              variant="outline"
              phx-click={@on_remove}
              disabled={@selected == nil}
            >
              <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
              Remove
            </.button>
          </div>
        </div>
      </.dialog_body>

      <.dialog_footer>
        <.button variant="outline" phx-click={@on_close || hide_modal(@id)}>
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          Close
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end

  @spec format_expires(any()) :: String.t()
  defp format_expires(nil), do: "Permanent"
  defp format_expires(""), do: "Permanent"
  defp format_expires(dt) when is_binary(dt), do: dt
  defp format_expires(_), do: "Permanent"
end
