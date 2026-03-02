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
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Select

  alias RetroHexChatWeb.Icons

  @doc "Renders the ignore list management dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :entries, :list,
    default: [],
    doc: "List of ignore entry maps with :nickname, :reason, and :expires_at keys"

  attr :selected, :string, default: nil, doc: "Nickname of the currently selected entry"
  attr :on_select, :any, default: nil, doc: "Row click callback (receives phx-value-nickname)"
  attr :show_ignore_add_dialog, :boolean, default: false, doc: "Show inline add sub-form"
  attr :on_add, :any, default: nil, doc: "Add button callback"
  attr :on_remove, :any, default: nil, doc: "Remove button callback"
  attr :on_close, :any, default: nil, doc: "Close button callback"

  @spec ignore_list_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def ignore_list_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header id={@id} title="Ignore List">
        <:icon><Icons.icon_dialog_ignore class="w-4 h-4" /></:icon>
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
                  <.table_cell class="text-xs">{to_string(entry.ignore_type)}</.table_cell>
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

    <%!-- Ignore Add Sub-Dialog --%>
    <.ignore_add_sub_form :if={@show_ignore_add_dialog} />
    """
  end

  # ── Sub-Forms ────────────────────────────────────────

  defp ignore_add_sub_form(assigns) do
    ~H"""
    <div class="dialog-overlay dialog-overlay--above">
      <div class="window dialog-window--sm">
        <div class="title-bar">
          <div class="title-bar-text">Add Ignore Entry</div>
          <div class="title-bar-controls">
            <button type="button" aria-label="Close" phx-click="close_ignore_add_dialog" />
          </div>
        </div>
        <div class="window-body dialog-body--p8">
          <form phx-submit="ignore_dialog_add_confirm" data-testid="ignore-add-form">
            <div class="field-row-stacked u-mb-8">
              <label class="text-xs font-bold" for="ignore-nick-input">Nickname:</label>
              <.input
                type="text"
                id="ignore-nick-input"
                name="nickname"
                maxlength="16"
                required
                autofocus
                class="u-w-full"
                data-testid="ignore-nick-input"
              />
            </div>
            <div class="field-row-stacked u-mb-8">
              <label class="text-xs font-bold" for="ignore-type-select">Type:</label>
              <.select
                :let={builder}
                id="ignore-type-select"
                name="type"
                value="all"
                label="All"
              >
                <.select_trigger builder={builder} class="h-7 text-xs w-full" />
                <.select_content builder={builder}>
                  <.select_group>
                    <.select_item builder={builder} value="all" label="All">All</.select_item>
                    <.select_item builder={builder} value="messages" label="Messages">
                      Messages
                    </.select_item>
                    <.select_item builder={builder} value="pms" label="PMs">PMs</.select_item>
                    <.select_item builder={builder} value="invites" label="Invites">
                      Invites
                    </.select_item>
                    <.select_item builder={builder} value="actions" label="Actions">
                      Actions
                    </.select_item>
                  </.select_group>
                </.select_content>
              </.select>
            </div>
            <div class="field-row-stacked u-mb-8">
              <label class="text-xs font-bold" for="ignore-duration-input">Duration:</label>
              <.input
                type="text"
                id="ignore-duration-input"
                name="duration"
                placeholder="Leave empty for permanent"
                class="u-w-full"
                data-testid="ignore-duration-input"
              />
            </div>
            <div class="dialog-buttons">
              <.button type="submit" size="sm">
                <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
                OK
              </.button>
              <.button
                type="button"
                size="sm"
                variant="outline"
                phx-click="close_ignore_add_dialog"
              >
                <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
                Cancel
              </.button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  @spec format_expires(any()) :: String.t()
  defp format_expires(nil), do: "Permanent"
  defp format_expires(""), do: "Permanent"
  defp format_expires(dt) when is_binary(dt), do: dt
  defp format_expires(_), do: "Permanent"
end
