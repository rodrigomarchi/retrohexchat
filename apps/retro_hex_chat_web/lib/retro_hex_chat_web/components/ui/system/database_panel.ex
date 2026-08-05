defmodule RetroHexChatWeb.Components.UI.System.DatabasePanel do
  @moduledoc """
  Diagnostic reports about the database, one at a time.

  Unlike the runtime listings, there is no single population to browse here:
  the catalogue is a set of unrelated questions — what is bloated, what is
  blocking, which indexes are never used — and each is a query against a live
  database. So the interaction is pick one, run it, read it, rather than filter
  and sort a standing list.

  Nothing runs until a report is chosen. These are real queries against the
  production database, some of them heavy, and a window that fired one merely
  by being opened would make the monitor a load of its own.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.AdminShared

  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :reports, :list, default: []
  attr :selected, :string, default: nil
  attr :table, :any, default: nil, doc: "%Admin.Table{} of the last run"
  attr :error, :string, default: nil
  attr :target, :any, default: nil
  attr :on_select, :string, required: true
  attr :testid, :string, default: "system-database"

  @spec database_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def database_panel(assigns) do
    ~H"""
    <div
      id={"#{@id}-database"}
      class="adm-dialog flex h-full min-h-0 flex-col gap-retro-8"
      data-testid={@testid}
    >
      <h3 class="flex min-w-0 shrink-0 items-center gap-1 text-xs font-bold">
        <Icons.icon_postgres class="h-4 w-4 shrink-0" />
        <span class="min-w-0 flex-1 truncate">{dgettext("dialogs", "Database reports")}</span>
        <span :if={@table} class="shrink-0 font-normal text-muted-foreground">
          {dgettext("dialogs", "%{count} rows", count: @table.total)}
        </span>
      </h3>

      <form
        id={"#{@id}-form"}
        class="shrink-0"
        phx-change={@on_select}
        phx-submit={@on_select}
        phx-target={@target}
      >
        <label for={"#{@id}-report"} class="mb-retro-2 block text-xs font-bold">
          {dgettext("dialogs", "Report")}
        </label>
        <select
          id={"#{@id}-report"}
          name="report"
          class="w-full bg-white px-retro-4 py-retro-2 text-sm shadow-retro-sunken"
        >
          <option value="" selected={is_nil(@selected)}>
            {dgettext("dialogs", "Choose a report…")}
          </option>
          <option
            :for={report <- @reports}
            value={report.name}
            selected={to_string(report.name) == @selected}
          >
            {report.title}
          </option>
        </select>
      </form>

      <p
        :if={@error}
        class="shrink-0 bg-black p-retro-6 font-mono text-xs text-red-400 shadow-retro-sunken"
        data-testid="system-database-error"
      >
        {@error}
      </p>

      <div class="retro-scrollbar min-h-0 flex-1 overflow-auto bg-white shadow-retro-sunken">
        <.admin_table
          table={@table}
          testid={"#{@testid}-table"}
          truncate
          empty_title={
            if(@selected,
              do: dgettext("dialogs", "The report returned no rows"),
              else: dgettext("dialogs", "Choose a report to run it")
            )
          }
        />
      </div>
    </div>
    """
  end
end
