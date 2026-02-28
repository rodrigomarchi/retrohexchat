defmodule RetroHexChatWeb.Components.UI.NotifyList do
  @moduledoc """
  Notify list dialog component for the showcase design system.

  Composed from dialog + table + button + checkbox primitives.
  Shows tracked nicks with online/offline status, last seen time,
  and Auto-Whois toggle. Supports Add/Edit/Remove CRUD actions.

  ## Usage

      <.notify_list id="notify-list" show={true} entries={@entries} />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Checkbox

  alias RetroHexChatWeb.Icons

  @doc "Renders the notify list dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :entries, :list,
    default: [],
    doc: "List of %{nickname, online (boolean), last_seen (string)} maps"

  attr :selected_entry, :string, default: nil, doc: "Currently selected nickname"
  attr :auto_whois, :boolean, default: false, doc: "Auto-Whois checkbox state"
  attr :on_select, :any, default: nil, doc: "Row click callback (phx-value-nickname)"
  attr :on_add, :any, default: nil, doc: "Add button callback"
  attr :on_edit, :any, default: nil, doc: "Edit button callback"
  attr :on_remove, :any, default: nil, doc: "Remove button callback"
  attr :on_toggle_auto_whois, :any, default: nil, doc: "Auto-Whois checkbox callback"
  attr :on_close, :any, default: nil, doc: "Close button callback"

  @spec notify_list(map()) :: Phoenix.LiveView.Rendered.t()
  def notify_list(assigns) do
    ~H"""
    <.dialog id={@id} show={@show}>
      <div data-testid="notify-list">
        <.dialog_header id={@id} title="Notify List">
          <:icon><Icons.icon_btn_bell class="w-4 h-4" /></:icon>
        </.dialog_header>

        <.dialog_body class="space-y-retro-8">
          <%!-- Auto-Whois toggle --%>
          <div class="flex items-center gap-retro-4">
            <.checkbox
              name="auto_whois"
              value={@auto_whois}
              phx-click={@on_toggle_auto_whois}
              id={"#{@id}-auto-whois"}
            />
            <label for={"#{@id}-auto-whois"} class="text-xs cursor-pointer select-none">
              Perform WHOIS on notify nicks when they come online
            </label>
          </div>

          <%!-- Entries table --%>
          <div class="max-h-[260px] overflow-y-auto retro-scrollbar">
            <.table>
              <.table_header>
                <.table_row>
                  <.table_head>Nick</.table_head>
                  <.table_head>Status</.table_head>
                  <.table_head>Last Seen</.table_head>
                </.table_row>
              </.table_header>
              <.table_body>
                <.table_row
                  :for={entry <- @entries}
                  class={
                    if(@selected_entry == entry.nickname,
                      do: "bg-selection-bg text-selection-fg",
                      else: ""
                    )
                  }
                  phx-click={@on_select}
                  phx-value-nickname={entry.nickname}
                  data-testid={"notify-list-row-#{entry.nickname}"}
                >
                  <.table_cell class="font-bold">{entry.nickname}</.table_cell>
                  <.table_cell>
                    <.online_status online={entry.online} />
                  </.table_cell>
                  <.table_cell class="text-xs">{Map.get(entry, :last_seen, "")}</.table_cell>
                </.table_row>
              </.table_body>
            </.table>
          </div>

          <%!-- CRUD buttons --%>
          <div class="flex gap-retro-4">
            <.button size="sm" variant="outline" phx-click={@on_add}>
              <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
              Add
            </.button>
            <.button
              size="sm"
              variant="outline"
              phx-click={@on_edit}
              disabled={@selected_entry == nil}
            >
              <:icon><Icons.icon_btn_edit class="w-4 h-4" /></:icon>
              Edit
            </.button>
            <.button
              size="sm"
              variant="outline"
              phx-click={@on_remove}
              disabled={@selected_entry == nil}
            >
              <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
              Remove
            </.button>
          </div>
        </.dialog_body>

        <.dialog_footer>
          <.button variant="outline" phx-click={@on_close || hide_modal(@id)}>
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            Close
          </.button>
        </.dialog_footer>
      </div>
    </.dialog>
    """
  end

  # ── Private helpers ───────────────────────────────────

  attr :online, :boolean, required: true

  defp online_status(%{online: true} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-retro-2 text-xs">
      <span class="w-2 h-2 rounded-full bg-success inline-block" /> Online
    </span>
    """
  end

  defp online_status(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-retro-2 text-xs text-muted-foreground">
      <span class="w-2 h-2 rounded-full bg-muted-foreground inline-block" /> Offline
    </span>
    """
  end
end
