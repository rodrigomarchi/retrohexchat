defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.UrlCatcherPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.UrlCatcher
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @sample_entries [
    %{
      url: "https://elixir-lang.org",
      posted_by: "alice",
      source: "#dev",
      timestamp: "14:32:01"
    },
    %{
      url: "https://phoenixframework.org",
      posted_by: "bob",
      source: "#dev",
      timestamp: "14:28:44"
    },
    %{
      url: "https://github.com/phoenixframework/phoenix",
      posted_by: "carol",
      source: "#random",
      timestamp: "13:55:10"
    },
    %{
      url: "https://hex.pm/packages/ecto",
      posted_by: "dave",
      source: "#dev",
      timestamp: "13:12:07"
    },
    %{
      url: "https://news.ycombinator.com/item?id=99999",
      posted_by: "eve",
      source: "#random",
      timestamp: "12:00:00"
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "URL Catcher",
       active_page: "url-catcher",
       entries: @sample_entries,
       channels: ["#dev", "#random"]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">URL Catcher</h2>

      <.showcase_card
        title="URL Catcher"
        description="All URLs posted in channels, sortable by column with channel filter and search."
      >
        <.button variant="outline" phx-click={show_modal("url-catcher-demo")}>
          <:icon><Icons.icon_link class="w-4 h-4" /></:icon>
          URL Catcher
        </.button>
        <.url_catcher
          id="url-catcher-demo"
          entries={@entries}
          entry_count={length(@entries)}
          channels={@channels}
        />
        <.code_example>
          &lt;.url_catcher
          id="url-catcher"
          entries=&#123;@entries&#125;
          entry_count=&#123;@entry_count&#125;
          channels=&#123;@channels&#125;
          sort_column=&#123;@sort_column&#125;
          sort_direction=&#123;@sort_direction&#125;
          on_sort="sort_urls"
          on_filter="filter_channel"
          on_search="search_urls"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Sorted by Nick (Ascending)"
        description="URL table with sort indicator on the Nick column."
      >
        <.button variant="outline" phx-click={show_modal("url-catcher-sorted")}>
          <:icon><Icons.icon_link class="w-4 h-4" /></:icon>
          URL Catcher (Sorted)
        </.button>
        <.url_catcher
          id="url-catcher-sorted"
          entries={Enum.sort_by(@entries, & &1.posted_by)}
          entry_count={length(@entries)}
          channels={@channels}
          sort_column={:posted_by}
          sort_direction={:asc}
        />
      </.showcase_card>

      <.showcase_card
        title="Channel Filtered"
        description="URL table showing only entries from #dev."
      >
        <.button variant="outline" phx-click={show_modal("url-catcher-filtered")}>
          <:icon><Icons.icon_link class="w-4 h-4" /></:icon>
          URL Catcher (Filtered)
        </.button>
        <.url_catcher
          id="url-catcher-filtered"
          entries={Enum.filter(@entries, &(&1.source == "#dev"))}
          entry_count={3}
          channels={@channels}
          filter_channel="#dev"
        />
      </.showcase_card>

      <.showcase_card
        title="Empty State"
        description="URL catcher with no captured URLs."
      >
        <.button variant="outline" phx-click={show_modal("url-catcher-empty")}>
          <:icon><Icons.icon_link class="w-4 h-4" /></:icon>
          URL Catcher (Empty)
        </.button>
        <.url_catcher id="url-catcher-empty" entries={[]} entry_count={0} />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
