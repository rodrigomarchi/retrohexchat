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

  attr :target, :any,
    default: nil,
    doc: "phx-target of the island owning the listing; without it there is no load-more"

  attr :on_load_more, :string,
    default: nil,
    doc: "Event the load-more button fires; omit for a listing that cannot page"

  attr :loading_more, :boolean, default: false

  @spec admin_table(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_table(%{table: %Table{}} = assigns) do
    ~H"""
    <div class={classes(["admin-table", @class])} data-testid={@testid}>
      <.list_empty_state :if={@table.rows == []} title={@empty_title} />

      <table :if={@table.rows != []} class="admin-table__grid w-full text-xs">
        <thead>
          <tr>
            <th :for={column <- @table.columns} class="admin-table__head">{column.label}</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={row <- @table.rows} class="admin-table__row" data-row-id={row.id}>
            <td :for={column <- @table.columns} class="admin-table__cell">
              {cell(row, column.key)}
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

  # Booleans read as marks rather than as the words "true"/"false", and a blank
  # cell says "nothing here" better than the string "nil" does.
  @spec cell(map(), atom()) :: String.t()
  defp cell(row, key), do: row |> Map.get(key) |> format_cell()

  defp format_cell(nil), do: ""
  defp format_cell(true), do: "✓"
  defp format_cell(false), do: "—"
  defp format_cell(%DateTime{} = at), do: DateTime.to_string(at)
  defp format_cell(value) when is_binary(value), do: value
  defp format_cell(value), do: to_string(value)
end
