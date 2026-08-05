defmodule RetroHexChatWeb.Components.UI.System.SourceBrowser do
  @moduledoc """
  The reading surface over one population of runtime entities.

  Processes, ports, sockets, ETS tables and applications are five windows over
  one interaction: narrow the population, order it by the column that answers
  the question, read the top of the result. That interaction is this component,
  and the five windows differ only in which source they hand it.

  The controls are deliberately few. There is no pagination beyond the row
  limit, because a monitor is read from the top — the process holding the most
  memory is on the first screen or the sort is wrong. The count strip is what
  makes that honest: it always says how many rows the filter matched, so a
  truncated listing never passes for a complete one.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.AdminShared
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Components.UI.Format
  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :icon, :atom, required: true
  attr :title, :string, required: true
  attr :table, :any, default: nil, doc: "%Admin.Table{}"
  attr :search, :string, default: nil
  attr :sort_by, :atom, default: nil
  attr :sort_dir, :atom, default: :desc, values: [:asc, :desc]
  attr :limit, :integer, default: 50
  attr :empty_title, :string, required: true
  attr :target, :any, default: nil
  attr :on_search, :string, required: true
  attr :on_sort, :string, required: true
  attr :on_refresh, :string, required: true
  attr :testid, :string, required: true

  @spec source_browser(map()) :: Phoenix.LiveView.Rendered.t()
  def source_browser(assigns) do
    ~H"""
    <div
      id={"#{@id}-browser"}
      class="adm-dialog flex h-full min-h-0 flex-col gap-retro-8"
      data-testid={@testid}
    >
      <div class="flex min-w-0 shrink-0 items-center gap-1 text-xs font-bold">
        {apply(Icons, @icon, [%{class: "h-4 w-4 shrink-0"}])}
        <span class="min-w-0 flex-1 truncate">{@title}</span>
        <span :if={@table} class="shrink-0 font-normal text-muted-foreground">
          {dgettext("dialogs", "%{shown} of %{total}",
            shown: Format.number(length(@table.rows)),
            total: Format.number(@table.total)
          )}
        </span>
      </div>

      <form
        id={"#{@id}-search"}
        class="flex shrink-0 items-end gap-retro-6"
        phx-change={@on_search}
        phx-submit={@on_search}
        phx-target={@target}
      >
        <div class="min-w-0 flex-1">
          <label for={"#{@id}-search-term"} class="mb-retro-2 block text-xs font-bold">
            {dgettext("dialogs", "Filter")}
          </label>
          <input
            id={"#{@id}-search-term"}
            name="search"
            type="text"
            value={@search}
            autocomplete="off"
            phx-debounce="250"
            class="w-full bg-white px-retro-4 py-retro-2 text-sm shadow-retro-sunken"
          />
        </div>

        <div class="w-[74px] shrink-0">
          <label for={"#{@id}-limit"} class="mb-retro-2 block text-xs font-bold">
            {dgettext("dialogs", "Rows")}
          </label>
          <input
            id={"#{@id}-limit"}
            name="limit"
            type="number"
            min="1"
            max="500"
            value={@limit}
            class="w-full bg-white px-retro-4 py-retro-2 text-sm shadow-retro-sunken"
          />
        </div>

        <.button
          type="button"
          size="sm"
          variant="outline"
          phx-click={@on_refresh}
          phx-target={@target}
        >
          <:icon><Icons.icon_btn_refresh class="h-[14px] w-[14px]" /></:icon>
          {dgettext("dialogs", "Refresh")}
        </.button>
      </form>

      <div class="retro-scrollbar min-h-0 flex-1 overflow-auto bg-white shadow-retro-sunken">
        <.admin_table
          table={@table}
          testid={"#{@testid}-table"}
          target={@target}
          on_sort={@on_sort}
          sort_by={@sort_by}
          sort_dir={@sort_dir}
          truncate
          empty_title={@empty_title}
        />
      </div>
    </div>
    """
  end
end
