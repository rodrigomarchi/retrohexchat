defmodule RetroHexChatWeb.Components.UI.AdminAuditLogDialog do
  @moduledoc """
  Admin Audit Log window — read-only administrative history.

  The log is a point-in-time read bounded by a row count and an optional actor,
  not a live feed. There is nothing to act on here, so the window has one form
  and one output pane.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.AdminShared
  import RetroHexChatWeb.Components.UI.DialogBanner
  import RetroHexChatWeb.Components.UI.RetroTable
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Input, only: [updown: 1]

  alias RetroHexChatWeb.Components.Diagrams
  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :target, :any, default: nil
  attr :text, :string, default: nil
  attr :table, :any, default: nil, doc: "%Table{} for the log"
  attr :last, :string, default: "20"
  attr :user, :string, default: ""
  attr :result, :any, default: nil
  attr :can_refresh, :boolean, default: false
  attr :on_refresh, :any, default: nil
  attr :on_load_more, :string, default: nil
  attr :on_cancel, :any, default: nil

  @doc "Framed variant with dialog chrome — used by the showcase page."
  @spec admin_audit_log_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_audit_log_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_cancel} class="max-w-2xl">
      <.dialog_header id={@id} title={dgettext("dialogs", "Audit Log")} on_close={@on_cancel}>
        <:icon><Icons.icon_notepad class="w-[16px] h-[16px]" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <.admin_audit_log_panel {assigns} />
      </.dialog_body>
    </.dialog>
    """
  end

  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :text, :string, default: nil
  attr :table, :any, default: nil, doc: "%Table{} for the log"
  attr :last, :string, default: "20"
  attr :user, :string, default: ""
  attr :result, :any, default: nil
  attr :can_refresh, :boolean, default: false
  attr :on_refresh, :any, default: nil
  attr :on_load_more, :string, default: nil

  @spec admin_audit_log_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_audit_log_panel(assigns) do
    ~H"""
    <div
      id={"#{@id}-content"}
      data-testid="admin-audit-log-panel"
      class="adm-dialog flex h-full min-h-0 flex-col gap-retro-8"
    >
      <.dialog_banner heading={dgettext("dialogs", "Who did what, and when")}>
        <:art>
          <Diagrams.diagram_dialog_preview
            kind={:ordered}
            title={dgettext("dialogs", "Audit Log")}
            lines={audit_lines(@table)}
            label={
              dgettext("dialogs", "A miniature of the log these actions are written to, newest first")
            }
          />
        </:art>
        <:glyph><Icons.icon_notepad class="h-8 w-8" /></:glyph>
        {dgettext(
          "dialogs",
          "Every privileged action writes a line here. A rejected action is written here too. The Danger Zone leaves this log alone, so the record survives the data."
        )}
      </.dialog_banner>

      <div class="adm-scroll min-h-0 flex-1 overflow-y-auto">
        <div class="space-y-retro-8">
          <form id="admin-audit-log-form" phx-submit={@on_refresh} phx-target={@target}>
            <div class="flex flex-wrap items-end gap-retro-6">
              <div class="w-[88px]">
                <label for="admin-audit-log-last" class="block text-xs font-bold mb-retro-2">
                  {dgettext("dialogs", "Last")}
                </label>
                <.updown disabled={not @can_refresh}>
                  <input
                    id="admin-audit-log-last"
                    name="last"
                    type="number"
                    min="1"
                    class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
                    value={@last}
                    disabled={not @can_refresh}
                  />
                </.updown>
              </div>
              <div class="flex-1 min-w-[160px]">
                <label for="admin-audit-log-user" class="block text-xs font-bold mb-retro-2">
                  {dgettext("dialogs", "User")}
                </label>
                <input
                  id="admin-audit-log-user"
                  name="user"
                  type="text"
                  class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
                  value={@user}
                  autocomplete="off"
                  disabled={not @can_refresh}
                />
              </div>
              <.button type="submit" size="sm" variant="outline" disabled={not @can_refresh}>
                <:icon><Icons.icon_btn_refresh class="w-[14px] h-[14px]" /></:icon>
                {dgettext("dialogs", "Refresh")}
              </.button>
            </div>
          </form>

          <div
            id="admin-audit-log-output"
            class="shadow-retro-sunken bg-white min-h-[190px] max-h-[260px] overflow-y-auto"
          >
            <.retro_table
              id="admin-audit-log-table"
              table={@table}
              text={@text}
              testid="admin-audit-log-table"
              target={@target}
              on_load_more={@on_load_more}
              empty_title={dgettext("dialogs", "No audit log entries found")}
            />
          </div>

          <.inline_result result={@result} />
        </div>
      </div>
    </div>
    """
  end

  @spec audit_lines(term()) :: [map()]
  defp audit_lines(table) do
    table
    |> table_rows(5)
    |> Enum.map(fn row ->
      actor = Map.get(row, :actor) || ""
      action = Map.get(row, :action) || ""
      %{text: String.trim(actor <> " " <> action), tone: :accent}
    end)
  end
end
