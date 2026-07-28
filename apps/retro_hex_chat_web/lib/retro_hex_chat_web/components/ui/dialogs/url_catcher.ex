defmodule RetroHexChatWeb.Components.UI.UrlCatcher do
  @moduledoc """
  URL catcher dialog component for the showcase design system.

  Composed from dialog + button + input/select primitives.
  Displays captured URLs with sortable columns (URL/Nick/Channel/Time),
  channel filter dropdown, and search input.

  ## Usage

      <.url_catcher id="url-catcher" show={true} entries={@entries} />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.ListStates
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Select

  alias RetroHexChatWeb.Icons

  @doc "Renders the URL catcher dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :entries, :list,
    default: [],
    doc: "List of CapturedURL structs"

  attr :dropped, :integer,
    default: 0,
    doc: "Links the session buffer discarded to stay within its bound"

  attr :sort_column, :atom, default: :timestamp, doc: "Column currently sorted on"
  attr :sort_direction, :atom, default: :desc, doc: "Sort direction: :asc or :desc"
  attr :filter_channel, :string, default: nil, doc: "Active channel filter value"
  attr :search_query, :string, default: "", doc: "Search input value"
  attr :channels, :list, default: [], doc: "List of channel name strings for the filter dropdown"
  attr :entry_count, :integer, default: 0, doc: "Total entries for the status line"
  attr :on_sort, :any, default: nil, doc: "Sort header click callback (phx-value-column)"
  attr :on_filter, :any, default: nil, doc: "Channel filter change callback"
  attr :on_search, :any, default: nil, doc: "Search input change callback"
  attr :timezone, :string, default: nil, doc: "Timezone for formatting timestamps"
  attr :on_close, :any, default: nil, doc: "Close button callback"

  @spec url_catcher(map()) :: Phoenix.LiveView.Rendered.t()
  def url_catcher(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} class="max-w-2xl" on_cancel={@on_close}>
      <div>
        <.dialog_header id={@id} title={dgettext("dialogs", "URL Catcher")} on_close={@on_close}>
          <:icon><Icons.icon_link class="w-4 h-4" /></:icon>
        </.dialog_header>

        <.dialog_body>
          <.url_catcher_panel
            id={@id}
            entries={@entries}
            dropped={@dropped}
            sort_column={@sort_column}
            sort_direction={@sort_direction}
            filter_channel={@filter_channel}
            search_query={@search_query}
            channels={@channels}
            entry_count={@entry_count}
            timezone={@timezone}
            on_sort={@on_sort}
            on_filter={@on_filter}
            on_search={@on_search}
            table_class="max-h-[300px]"
          />
        </.dialog_body>

        <.dialog_footer>
          <.button variant="outline" phx-click={@on_close || hide_modal(@id)}>
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Close")}
          </.button>
        </.dialog_footer>
      </div>
    </.dialog>
    """
  end

  @doc """
  Renders the URL catcher content panel (filters + table + status line) without
  any frame — compose it inside a dialog or a desktop window body.
  """
  attr :id, :string, required: true
  attr :entries, :list, default: [], doc: "List of CapturedURL structs"
  attr :dropped, :integer, default: 0, doc: "Links discarded to stay within the buffer's bound"
  attr :sort_column, :atom, default: :timestamp
  attr :sort_direction, :atom, default: :desc
  attr :filter_channel, :string, default: nil
  attr :search_query, :string, default: ""
  attr :channels, :list, default: []
  attr :entry_count, :integer, default: 0
  attr :on_sort, :any, default: nil
  attr :on_filter, :any, default: nil
  attr :on_search, :any, default: nil
  attr :timezone, :string, default: nil

  attr :table_class, :any,
    default: nil,
    doc: "extra classes for the scrollable table region (e.g. a max-height cap in a dialog)"

  @spec url_catcher_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def url_catcher_panel(assigns) do
    ~H"""
    <div
      id={"#{@id}-panel-root"}
      class="contents"
    >
      <.focus_wrap id={"#{@id}-focus-wrap"} class="contents">
        <div
          id={"#{@id}-content"}
          phx-hook="URLCatcherHook"
          data-testid="url-catcher"
          role="dialog"
          aria-modal="false"
          tabindex="0"
          phx-mounted={JS.focus(to: "##{@id}-content")}
          class="uc-dialog flex h-full min-h-0 flex-col gap-retro-8"
        >
          <%!-- Filters row --%>
          <div class="uc-toolbar">
            <%!-- Channel filter --%>
            <form phx-change={@on_filter} class="uc-filter-form">
              <.select
                :let={builder}
                id="url-catcher-channel-filter"
                name="channel"
                value={@filter_channel || ""}
                label={@filter_channel || dgettext("dialogs", "All Channels")}
                placeholder={dgettext("dialogs", "All Channels")}
              >
                <.select_trigger builder={builder} class="uc-select-trigger h-7 text-xs" />
                <.select_content builder={builder}>
                  <.select_group>
                    <.select_item
                      builder={builder}
                      value=""
                      label={dgettext("dialogs", "All Channels")}
                    >
                      {dgettext("dialogs", "All Channels")}
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
            <form phx-change={@on_search} phx-submit={@on_search} class="uc-search-form">
              <.input
                type="text"
                value={@search_query}
                placeholder={dgettext("dialogs", "Search URLs...")}
                class="uc-search-input"
                phx-debounce="300"
                name="query"
                data-testid="url-catcher-search"
              />
              <.button type="submit" size="sm" variant="outline" class="uc-action-button">
                <:icon><Icons.icon_btn_find class="w-4 h-4" /></:icon>
                {dgettext("dialogs", "Search")}
              </.button>
            </form>
          </div>

          <div class="uc-sort-row retro-scrollbar">
            <.sort_button
              label={dgettext("dialogs", "URL")}
              column={:url}
              active={@sort_column}
              direction={@sort_direction}
              on_sort={@on_sort}
            />
            <.sort_button
              label={dgettext("dialogs", "Nick")}
              column={:posted_by}
              active={@sort_column}
              direction={@sort_direction}
              on_sort={@on_sort}
            />
            <.sort_button
              label={dgettext("dialogs", "Channel")}
              column={:source}
              active={@sort_column}
              direction={@sort_direction}
              on_sort={@on_sort}
            />
            <.sort_button
              label={dgettext("dialogs", "Time")}
              column={:timestamp}
              active={@sort_column}
              direction={@sort_direction}
              on_sort={@on_sort}
            />
          </div>

          <%!-- URL list --%>
          <div class={classes(["uc-entry-list flex-1 overflow-y-auto retro-scrollbar", @table_class])}>
            <.list_empty_state
              :if={@entries == []}
              class="uc-empty-state"
              title={dgettext("dialogs", "No URLs captured yet.")}
              text={dgettext("dialogs", "Shared links will appear here.")}
            />

            <%!-- The catcher keeps only the most recent links, so once it is
                  full the oldest are gone for good. The count is the only
                  record that they existed, so this one stays numeric rather
                  than becoming an ornament. --%>
            <.list_count_strip
              shown={length(@entries)}
              total={length(@entries) + @dropped}
              data-testid="url-catcher-dropped"
            />

            <article
              :for={entry <- @entries}
              class="uc-entry"
              data-testid="url-catcher-row"
              data-url={entry.url}
            >
              <a
                href={entry.url}
                target="_blank"
                rel="noopener noreferrer"
                class="uc-entry-url text-link hover:underline"
              >
                {entry.url}
              </a>
              <div
                :if={Map.get(entry, :preview_title)}
                class="uc-preview-title"
                data-testid="url-catcher-preview-title"
              >
                {Map.get(entry, :preview_title)}
              </div>
              <div class="uc-entry-meta">
                <span>
                  <span class="uc-meta-label">{dgettext("dialogs", "Nick")}</span>
                  {entry.posted_by}
                </span>
                <span>
                  <span class="uc-meta-label">{dgettext("dialogs", "Channel")}</span>
                  {entry.source}
                </span>
                <span>
                  <span class="uc-meta-label">{dgettext("dialogs", "Time")}</span>
                  {format_timestamp(Map.get(entry, :timestamp), @timezone)}
                </span>
              </div>
            </article>
          </div>

          <%!-- Status line --%>
          <div class="uc-status-line shadow-retro-status shrink-0 px-retro-4 py-[2px] text-xs text-muted-foreground">
            {entry_count_label(@entry_count)}
          </div>
        </div>
      </.focus_wrap>
    </div>
    """
  end

  # ── Private helpers ───────────────────────────────────

  attr :label, :string, required: true
  attr :column, :atom, required: true
  attr :active, :atom, required: true
  attr :direction, :atom, required: true
  attr :on_sort, :any, default: nil

  defp sort_button(assigns) do
    ~H"""
    <.button
      type="button"
      variant="ghost"
      size="sm"
      class="uc-sort-button"
      phx-click={@on_sort}
      phx-value-column={Atom.to_string(@column)}
    >
      <:icon><Icons.icon_btn_down class="w-4 h-4" /></:icon>
      {@label}
      <.sort_indicator col={@column} active={@active} dir={@direction} />
    </.button>
    """
  end

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

  @spec format_timestamp(any(), String.t() | nil) :: String.t()
  defp format_timestamp(%DateTime{} = dt, timezone) when is_binary(timezone) do
    dt |> RetroHexChatWeb.Timezone.shift(timezone) |> Calendar.strftime("%H:%M")
  end

  defp format_timestamp(val, _timezone) when is_binary(val), do: val
  defp format_timestamp(_, _), do: ""

  @spec entry_count_label(integer()) :: String.t()
  defp entry_count_label(0), do: dgettext("dialogs", "No URLs captured")
  defp entry_count_label(1), do: dgettext("dialogs", "1 URL")
  defp entry_count_label(n), do: dngettext("dialogs", "1 URL", "%{count} URLs", n)
end
