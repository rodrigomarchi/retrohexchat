defmodule RetroHexChatWeb.Components.UI.AdminShared do
  @moduledoc """
  Presentation shared by every admin window.

  The admin surfaces are separate windows over one visual language: each runs a
  privileged command and reports the outcome in the same black inline strip.
  `inline_result/1` is that strip; `present?/1` is the blank-string guard the
  read-only panes use before falling back to an empty state; `admin_table/1`
  renders a listing as rows.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ListStates

  alias RetroHexChat.Admin.Table
  alias RetroHexChatWeb.Components.UI.Format
  alias RetroHexChatWeb.Icons

  @doc """
  Outcome strip for a privileged command — green on success, red on error.

  Renders nothing while `result` is nil, so a window that has not run a command
  yet shows no strip at all.
  """
  attr :result, :any, default: nil

  @spec inline_result(map()) :: Phoenix.LiveView.Rendered.t()
  def inline_result(assigns) do
    ~H"""
    <div
      :if={@result}
      class={[
        "shadow-retro-sunken bg-black font-mono text-xs p-retro-6",
        if(Map.get(@result, :status) == :error, do: "text-red-400", else: "text-green-400")
      ]}
      data-testid="admin-inline-result"
    >
      {Map.get(@result, :message, "")}
    </div>
    """
  end

  @doc "Whether a value is a string with something other than whitespace in it."
  @spec present?(term()) :: boolean()
  def present?(value), do: is_binary(value) and String.trim(value) != ""

  @doc """
  Renders an admin listing as rows.

  Falls back to the preformatted text when the command did not carry a table —
  a handler that has not been converted yet still renders exactly as before,
  which is what let the conversion happen one command at a time.

  The count strip appears only when the listing is truncated, so an admin can
  tell "these are all of them" from "these are the first hundred" without
  counting.
  """
  attr :table, :any, default: nil, doc: "%Admin.Table{} or nil"
  attr :text, :string, default: nil, doc: "Preformatted fallback"
  attr :empty_title, :string, required: true
  attr :testid, :string, required: true
  attr :class, :string, default: nil
  attr :table_class, :string, default: nil

  attr :target, :any,
    default: nil,
    doc: "phx-target of the island owning the listing; without it there is no load-more"

  attr :on_load_more, :string,
    default: nil,
    doc: "Event the load-more button fires; omit for a listing that cannot page"

  attr :loading_more, :boolean, default: false

  attr :on_sort, :string,
    default: nil,
    doc: "Event a sortable heading fires, carrying the column key; omit to leave headings inert"

  attr :sort_by, :atom, default: nil, doc: "The column currently ordering the rows"
  attr :sort_dir, :atom, default: :desc, values: [:asc, :desc]

  attr :truncate, :boolean,
    default: false,
    doc: """
    Bound every cell's width, showing the full value on hover.

    Off by default: the audit log and the user listings hold short values and
    are read in full. The runtime listings hold module names and MFAs long
    enough to push the table wider than its window, which pushes the leftmost
    column — the one naming the row — out of sight entirely.
    """

  @spec admin_table(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_table(%{table: %Table{}} = assigns) do
    ~H"""
    <div class={classes(["admin-table", @class])} data-testid={@testid}>
      <.list_empty_state :if={@table.rows == []} title={@empty_title} />

      <table
        :if={@table.rows != []}
        class={classes(["admin-table__grid w-full text-xs", @table_class])}
      >
        <thead>
          <tr>
            <th :for={column <- @table.columns} class="admin-table__head">
              <.column_heading
                column={column}
                on_sort={@on_sort}
                target={@target}
                sort_by={@sort_by}
                sort_dir={@sort_dir}
              />
            </th>
          </tr>
        </thead>
        <tbody>
          <tr :for={row <- @table.rows} class="admin-table__row" data-row-id={row.id}>
            <td
              :for={column <- @table.columns}
              class={["admin-table__cell", @truncate && "admin-table__cell--bounded"]}
              title={@truncate && cell(row, column)}
            >
              {cell(row, column)}
            </td>
          </tr>
        </tbody>
      </table>

      <.list_count_strip :if={@table.total} shown={length(@table.rows)} total={@table.total} />

      <.list_load_more_button
        :if={@on_load_more && Table.has_more?(@table)}
        target={@target}
        event={@on_load_more}
        loading={@loading_more}
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

  def admin_table(assigns) do
    ~H"""
    <pre
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
      class="admin-table__sort inline-flex w-full items-center gap-1"
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
    {@column.label}
    """
  end

  # Booleans read as marks rather than as the words "true"/"false", and a blank
  # cell says "nothing here" better than the string "nil" does. What a figure
  # means is the column's business, so the format travels with it.
  @spec cell(map(), Table.column()) :: String.t()
  defp cell(row, column) do
    Format.cell(Map.get(row, column.key), Map.get(column, :format, :text))
  end
end
