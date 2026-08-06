defmodule RetroHexChatWeb.Components.UI.RetroTable do
  @moduledoc """
  The listing surface: a `RetroHexChat.Table` drawn as a Win98 list view.

  Every window that shows rows shows them here, so ordering, resizing, choosing
  columns and reading a selection work the same everywhere. The alternative —
  each window styling its own `<table>` — is what made two listings side by side
  disagree about padding, striping and what a sortable heading looks like.

  ## What the server owns and what the browser owns

  Ordering and pagination are the server's: they change which rows exist, so
  they travel as events (`on_sort`, `on_load_more`) and come back as a new
  table. Column width, column visibility and the selection are the browser's:
  they change nothing about the data, and routing them through the server would
  put a round-trip inside a drag.

  That split is why `RetroTableHook` re-asserts its state on every `updated()`.
  The server re-renders the header and the rows without knowing that a column is
  70px wide or hidden, and the hook puts that back — the same arrangement the
  window manager uses for window geometry.

  ## The interactions

    * drag a heading's right edge to resize it; double-click that edge to fit
      the column to its widest visible cell
    * right-click the header row (or press the Menu key with focus in the
      table) to choose which columns show
    * arrows, Home/End and PageUp/PageDown move the selection; Shift extends it
      and Ctrl adds to it; Ctrl+C copies the selected rows as tab-separated text
    * click a sortable heading to order by it, again to reverse

  Widths are measured once from the first render and then held fixed, so a
  refresh that changes the longest value no longer makes every column jump.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ContextMenu
  import RetroHexChatWeb.Components.UI.ListStates

  alias RetroHexChat.Table
  alias RetroHexChatWeb.Components.UI.Format
  alias RetroHexChatWeb.Icons

  @numeric_formats [:bytes, :number, :duration_ms, :percent]

  @doc """
  Renders a listing as rows.

  Falls back to the preformatted text when there is no table, so a command that
  has not been converted yet still renders exactly as before — which is what let
  the conversion happen one command at a time.

  The count strip appears only when the listing is truncated, so a reader can
  tell "these are all of them" from "these are the first hundred" without
  counting.
  """
  attr :id, :string, required: true, doc: "Anchors the hook, the header menu and the column state"
  attr :table, :any, default: nil, doc: "%RetroHexChat.Table{} or nil"
  attr :text, :string, default: nil, doc: "Preformatted fallback"
  attr :empty_title, :string, required: true
  attr :testid, :string, required: true
  attr :class, :string, default: nil

  attr :fit_pane, :boolean,
    default: false,
    doc: """
    Divide the pane between the columns instead of letting the table outgrow it.

    Off by default, because a runtime listing carries module names and MFAs that
    are worth scrolling sideways to read in full. Switch it on where the window
    is the point — the Oban panel stacks eight listings in one pane, and a table
    that reached past it would put a horizontal scrollbar under each one.

    It governs the first paint, which is the one that matters: widths are
    measured from it, so a table that starts too wide stays too wide.
    """

  attr :target, :any,
    default: nil,
    doc: "phx-target of the island owning the listing; without it there is no load-more"

  attr :on_load_more, :string,
    default: nil,
    doc: "Event the load-more button fires; omit for a listing that cannot page"

  attr :on_sort, :string,
    default: nil,
    doc: "Event a sortable heading fires, carrying the column key; omit to leave headings inert"

  attr :sort_by, :atom, default: nil, doc: "The column currently ordering the rows"
  attr :sort_dir, :atom, default: :desc, values: [:asc, :desc]

  attr :truncate, :boolean,
    default: false,
    doc: """
    Bound every cell's width before the browser has measured anything.

    Off by default: the audit log and the user listings hold short values and are
    read in full. The runtime listings hold module names and MFAs long enough to
    push the table wider than its window, which pushes the leftmost column — the
    one naming the row — out of sight entirely. Once the hook has fixed the
    widths this stops mattering, so it only governs the first paint and the
    no-JS case.
    """

  @spec retro_table(map()) :: Phoenix.LiveView.Rendered.t()
  def retro_table(%{table: %Table{}} = assigns) do
    ~H"""
    <div
      id={@id}
      class={classes(["retro-table", @class])}
      data-testid={@testid}
      phx-hook="RetroTableHook"
      data-fit={@fit_pane && "pane"}
    >
      <.list_empty_state :if={@table.rows == []} title={@empty_title} />

      <table
        :if={@table.rows != []}
        class="retro-table__grid"
        role="grid"
        aria-multiselectable="true"
        data-retro-table-grid
      >
        <thead>
          <tr class="retro-table__head-row" data-retro-table-head-row>
            <th
              :for={column <- @table.columns}
              scope="col"
              class={["retro-table__head", numeric?(column) && "retro-table__head--numeric"]}
              data-column={column.key}
              aria-sort={aria_sort(column, @on_sort, @sort_by, @sort_dir)}
            >
              <.column_heading
                column={column}
                on_sort={@on_sort}
                target={@target}
                sort_by={@sort_by}
                sort_dir={@sort_dir}
              />
              <span class="retro-table__resizer" data-retro-table-resizer aria-hidden="true" />
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            :for={row <- @table.rows}
            class="retro-table__row"
            data-row-id={row.id}
            tabindex="-1"
            aria-selected="false"
          >
            <td
              :for={column <- @table.columns}
              class={[
                "retro-table__cell",
                numeric?(column) && "retro-table__cell--numeric",
                @truncate && "retro-table__cell--bounded"
              ]}
              data-column={column.key}
              title={@truncate && cell(row, column)}
            >
              {cell(row, column)}
            </td>
          </tr>
        </tbody>
      </table>

      <.column_menu :if={@table.rows != []} id={@id} columns={@table.columns} />

      <.list_count_strip :if={@table.total} shown={length(@table.rows)} total={@table.total} />

      <.list_load_more_button
        :if={@on_load_more && Table.has_more?(@table)}
        target={@target}
        event={@on_load_more}
        testid={"#{@testid}-load-more"}
      />

      <.list_end_marker
        :if={@on_load_more && @table.rows != [] && not Table.has_more?(@table)}
        variant={:start}
        testid={"#{@testid}-end"}
      />
    </div>
    """
  end

  def retro_table(assigns) do
    ~H"""
    <pre
      id={@id}
      class={
        classes([
          "shadow-retro-sunken bg-white overflow-y-auto p-retro-8 text-xs whitespace-pre-wrap",
          @class
        ])
      }
      data-testid={@testid}
    ><%= @text || "" %></pre>
    """
  end

  # The menu is rendered with the rows and hidden until the header is
  # right-clicked, so which columns exist stays a server-side fact and the hook
  # only has to toggle marks. Building it in JavaScript instead would put
  # markup — and the labels a translator works on — outside the templates.
  attr :id, :string, required: true
  attr :columns, :list, required: true

  defp column_menu(assigns) do
    ~H"""
    <.context_menu
      id={"#{@id}-columns"}
      class="retro-table__menu u-hidden"
      data-retro-table-menu
      aria-label={dgettext("dialogs", "Columns")}
    >
      <.context_menu_label>{dgettext("dialogs", "Columns")}</.context_menu_label>
      <.context_menu_separator />
      <.context_menu_item
        :for={column <- @columns}
        role="menuitemcheckbox"
        aria-checked="true"
        testid={"#{@id}-column-#{column.key}"}
        data-retro-table-column={column.key}
      >
        <:icon>
          <Icons.icon_check_thin class="retro-table__menu-check h-[14px] w-[14px]" />
        </:icon>
        {column.label}
      </.context_menu_item>
      <.context_menu_separator />
      <.context_menu_item testid={"#{@id}-columns-reset"} data-retro-table-columns-reset>
        <:icon><Icons.icon_table_grid class="h-[14px] w-[14px]" /></:icon>
        {dgettext("dialogs", "Show all columns")}
      </.context_menu_item>
    </.context_menu>
    """
  end

  # A heading is a button only where the listing can actually be reordered:
  # every other one stays plain text, so nothing invites a click that does
  # nothing. The arrow marks the column currently in force and which way.
  attr :column, :map, required: true
  attr :on_sort, :string, default: nil
  attr :target, :any, default: nil
  attr :sort_by, :atom, default: nil
  attr :sort_dir, :atom, default: :desc

  defp column_heading(%{on_sort: on_sort, column: %{sortable: true}} = assigns)
       when is_binary(on_sort) do
    assigns = assign(assigns, :active?, assigns.sort_by == assigns.column.key)

    ~H"""
    <button
      type="button"
      class="retro-table__sort inline-flex w-full items-center gap-1"
      phx-click={@on_sort}
      phx-target={@target}
      phx-value-column={@column.key}
      aria-label={@column.label}
      data-active={to_string(@active?)}
    >
      <span class="truncate">{@column.label}</span>
      <Icons.icon_sort_ascending :if={@active? and @sort_dir == :asc} class="h-3 w-3 shrink-0" />
      <Icons.icon_sort_descending :if={@active? and @sort_dir == :desc} class="h-3 w-3 shrink-0" />
      <Icons.icon_sort_none :if={not @active?} class="h-3 w-3 shrink-0 opacity-40" />
    </button>
    """
  end

  defp column_heading(assigns) do
    ~H"""
    <span class="retro-table__label">{@column.label}</span>
    """
  end

  # Screen readers announce the ordering from the heading itself, so a column
  # that cannot be reordered says nothing rather than claiming to be unsorted.
  @spec aria_sort(Table.column(), String.t() | nil, atom(), atom()) :: String.t() | nil
  defp aria_sort(%{sortable: true} = column, on_sort, sort_by, sort_dir)
       when is_binary(on_sort) do
    cond do
      column.key != sort_by -> "none"
      sort_dir == :asc -> "ascending"
      true -> "descending"
    end
  end

  defp aria_sort(_column, _on_sort, _sort_by, _sort_dir), do: nil

  # A figure is read against the figures above and below it, which only works
  # when they share a right edge. Text is read from its left.
  @spec numeric?(Table.column()) :: boolean()
  defp numeric?(column), do: Map.get(column, :format, :text) in @numeric_formats

  # Booleans read as marks rather than as the words "true"/"false", and a blank
  # cell says "nothing here" better than the string "nil" does. What a figure
  # means is the column's business, so the format travels with it.
  @spec cell(map(), Table.column()) :: String.t()
  defp cell(row, column) do
    Format.cell(Map.get(row, column.key), Map.get(column, :format, :text))
  end
end
