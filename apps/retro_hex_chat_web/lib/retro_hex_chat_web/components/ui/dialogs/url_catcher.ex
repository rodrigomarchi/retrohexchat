defmodule RetroHexChatWeb.Components.UI.UrlCatcher do
  @moduledoc """
  URL catcher dialog component for the showcase design system.

  Composed from dialog + table + button + input primitives.
  Displays captured URLs with sortable columns (URL/Nick/Channel/Time),
  channel filter dropdown, and search input.

  ## Usage

      <.url_catcher id="url-catcher" show={true} entries={@entries} />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Select

  alias RetroHexChatWeb.Icons

  @doc "Renders the URL catcher dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :entries, :list,
    default: [],
    doc: "List of %{url, nick, channel, timestamp} maps"

  attr :sort_column, :atom, default: :timestamp, doc: "Column currently sorted on"
  attr :sort_direction, :atom, default: :desc, doc: "Sort direction: :asc or :desc"
  attr :filter_channel, :string, default: nil, doc: "Active channel filter value"
  attr :search_query, :string, default: "", doc: "Search input value"
  attr :channels, :list, default: [], doc: "List of channel name strings for the filter dropdown"
  attr :entry_count, :integer, default: 0, doc: "Total entries for the status line"
  attr :on_sort, :any, default: nil, doc: "Sort header click callback (phx-value-column)"
  attr :on_filter, :any, default: nil, doc: "Channel filter change callback"
  attr :on_search, :any, default: nil, doc: "Search input change callback"
  attr :on_close, :any, default: nil, doc: "Close button callback"

  @spec url_catcher(map()) :: Phoenix.LiveView.Rendered.t()
  def url_catcher(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} class="max-w-2xl">
      <div data-testid="url-catcher">
        <.dialog_header id={@id} title="URL Catcher">
          <:icon><Icons.icon_link class="w-4 h-4" /></:icon>
        </.dialog_header>

        <.dialog_body class="space-y-retro-8">
          <%!-- Filters row --%>
          <div class="flex items-center gap-retro-4">
            <%!-- Channel filter --%>
            <form phx-change={@on_filter}>
              <.select
                :let={builder}
                id="url-catcher-channel-filter"
                name="filter_channel"
                value={@filter_channel || ""}
                label={@filter_channel || "All Channels"}
                placeholder="All Channels"
              >
                <.select_trigger builder={builder} class="h-7 text-xs w-[140px]" />
                <.select_content builder={builder}>
                  <.select_group>
                    <.select_item builder={builder} value="" label="All Channels">
                      All Channels
                    </.select_item>
                    <.select_item
                      :for={ch <- @channels}
                      builder={builder}
                      value={ch}
                      label={ch}
                    >
                      {ch}
                    </.select_item>
                  </.select_group>
                </.select_content>
              </.select>
            </form>

            <%!-- Search --%>
            <.input
              type="text"
              value={@search_query}
              placeholder="Search URLs..."
              class="flex-1"
              phx-change={@on_search}
              phx-debounce="300"
              name="search"
              data-testid="url-catcher-search"
            />
            <.button size="sm" variant="outline" phx-click={@on_search}>
              <:icon><Icons.icon_btn_find class="w-4 h-4" /></:icon>
              Search
            </.button>
          </div>

          <%!-- URL table --%>
          <div class="max-h-[300px] overflow-y-auto retro-scrollbar">
            <.table>
              <.table_header>
                <.table_row>
                  <.table_head>
                    <.button
                      type="button"
                      variant="ghost"
                      size="sm"
                      class="gap-retro-2 hover:underline p-0 h-auto"
                      phx-click={@on_sort}
                      phx-value-column="url"
                    >
                      <:icon><Icons.icon_btn_down class="w-4 h-4" /></:icon>
                      URL <.sort_indicator col={:url} active={@sort_column} dir={@sort_direction} />
                    </.button>
                  </.table_head>
                  <.table_head>
                    <.button
                      type="button"
                      variant="ghost"
                      size="sm"
                      class="gap-retro-2 hover:underline p-0 h-auto"
                      phx-click={@on_sort}
                      phx-value-column="nick"
                    >
                      <:icon><Icons.icon_btn_down class="w-4 h-4" /></:icon>
                      Nick <.sort_indicator col={:nick} active={@sort_column} dir={@sort_direction} />
                    </.button>
                  </.table_head>
                  <.table_head>
                    <.button
                      type="button"
                      variant="ghost"
                      size="sm"
                      class="gap-retro-2 hover:underline p-0 h-auto"
                      phx-click={@on_sort}
                      phx-value-column="channel"
                    >
                      <:icon><Icons.icon_btn_down class="w-4 h-4" /></:icon>
                      Channel
                      <.sort_indicator col={:channel} active={@sort_column} dir={@sort_direction} />
                    </.button>
                  </.table_head>
                  <.table_head>
                    <.button
                      type="button"
                      variant="ghost"
                      size="sm"
                      class="gap-retro-2 hover:underline p-0 h-auto"
                      phx-click={@on_sort}
                      phx-value-column="timestamp"
                    >
                      <:icon><Icons.icon_btn_down class="w-4 h-4" /></:icon>
                      Time
                      <.sort_indicator col={:timestamp} active={@sort_column} dir={@sort_direction} />
                    </.button>
                  </.table_head>
                </.table_row>
              </.table_header>
              <.table_body>
                <.table_row :for={entry <- @entries} data-testid="url-catcher-row">
                  <.table_cell class="max-w-[200px] truncate">
                    <a
                      href={entry.url}
                      target="_blank"
                      rel="noopener noreferrer"
                      class="text-link hover:underline"
                    >
                      {entry.url}
                    </a>
                  </.table_cell>
                  <.table_cell>{entry.nick}</.table_cell>
                  <.table_cell>{Map.get(entry, :channel, "")}</.table_cell>
                  <.table_cell class="text-xs text-muted-foreground whitespace-nowrap">
                    {Map.get(entry, :timestamp, "")}
                  </.table_cell>
                </.table_row>
              </.table_body>
            </.table>
          </div>

          <%!-- Status line --%>
          <div class="shadow-retro-status px-retro-4 py-[2px] text-xs text-muted-foreground">
            {entry_count_label(@entry_count)}
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

  attr :col, :atom, required: true
  attr :active, :atom, required: true
  attr :dir, :atom, required: true

  defp sort_indicator(%{col: col, active: col, dir: :asc} = assigns) do
    ~H|<span class="text-[10px]">▲</span>|
  end

  defp sort_indicator(%{col: col, active: col, dir: :desc} = assigns) do
    ~H|<span class="text-[10px]">▼</span>|
  end

  defp sort_indicator(assigns), do: ~H""

  @spec entry_count_label(integer()) :: String.t()
  defp entry_count_label(0), do: "No URLs captured"
  defp entry_count_label(1), do: "1 URL"
  defp entry_count_label(n), do: "#{n} URLs"
end
