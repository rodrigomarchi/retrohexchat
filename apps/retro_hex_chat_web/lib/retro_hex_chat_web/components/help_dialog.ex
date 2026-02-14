defmodule RetroHexChatWeb.Components.HelpDialog do
  @moduledoc """
  Windows 98 CHM-style Help dialog with Contents/Index/Search tabs
  and a content pane for rendering help topics.
  """
  use Phoenix.Component

  import Phoenix.HTML, only: [raw: 1]

  attr :visible, :boolean, required: true
  attr :active_tab, :string, required: true
  attr :selected_topic, :map, default: nil
  attr :topics_by_category, :list, required: true
  attr :index_keywords, :list, required: true
  attr :index_filter, :string, default: ""
  attr :search_query, :string, default: ""
  attr :search_results, :list, default: []

  @spec help_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def help_dialog(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      data-testid="help-dialog"
    >
      <div class="window help-dialog">
        <div class="title-bar">
          <div class="title-bar-text">RetroHexChat Help</div>
          <div class="title-bar-controls">
            <button aria-label="Close" data-testid="help-dialog-close" phx-click="close_help">
            </button>
          </div>
        </div>
        <div class="window-body help-split">
          <%!-- Navigation pane --%>
          <div class="help-nav" data-testid="help-nav-pane">
            <menu role="tablist" class="help-nav-tabs">
              <button
                role="tab"
                aria-selected={@active_tab == "contents"}
                data-testid="help-tab-contents"
                phx-click="help_tab"
                phx-value-tab="contents"
              >
                Contents
              </button>
              <button
                role="tab"
                aria-selected={@active_tab == "index"}
                data-testid="help-tab-index"
                phx-click="help_tab"
                phx-value-tab="index"
              >
                Index
              </button>
              <button
                role="tab"
                aria-selected={@active_tab == "search"}
                data-testid="help-tab-search"
                phx-click="help_tab"
                phx-value-tab="search"
              >
                Search
              </button>
            </menu>

            <div class="help-nav-content">
              <%!-- Contents tab --%>
              <div :if={@active_tab == "contents"}>
                <ul class="tree-view">
                  <li :for={{category, topics} <- @topics_by_category}>
                    <details>
                      <summary>{category}</summary>
                      <ul>
                        <li
                          :for={topic <- topics}
                          class={
                            if(@selected_topic && @selected_topic.id == topic.id,
                              do: "help-tree-active",
                              else: ""
                            )
                          }
                          phx-click="help_select_topic"
                          phx-value-id={topic.id}
                          class="u-cursor-pointer"
                        >
                          {topic.title}
                        </li>
                      </ul>
                    </details>
                  </li>
                </ul>
              </div>

              <%!-- Index tab --%>
              <div :if={@active_tab == "index"}>
                <input
                  type="text"
                  placeholder="Type a keyword..."
                  value={@index_filter}
                  phx-keyup="help_index_filter"
                  data-testid="help-index-filter"
                  class="help-search-input"
                />
                <div class="help-search-scroll">
                  <div
                    :for={{keyword, topic_id} <- @index_keywords}
                    class="help-index-item"
                    phx-click="help_select_topic"
                    phx-value-id={topic_id}
                    data-testid={"help-index-#{keyword}"}
                  >
                    {keyword}
                  </div>
                </div>
              </div>

              <%!-- Search tab --%>
              <div :if={@active_tab == "search"}>
                <div class="help-search-row">
                  <input
                    type="text"
                    placeholder="Search help..."
                    value={@search_query}
                    phx-keyup="help_search_input"
                    phx-key="Enter"
                    data-testid="help-search-input"
                    class="help-search-field"
                  />
                  <button
                    type="button"
                    data-testid="help-search-btn"
                    phx-click="help_search"
                    phx-value-query={@search_query}
                    class="help-search-btn"
                  >
                    Go
                  </button>
                </div>
                <div class="help-index-scroll">
                  <div
                    :for={result <- @search_results}
                    class="help-search-result"
                    phx-click="help_select_topic"
                    phx-value-id={result.id}
                    data-testid={"help-result-#{result.id}"}
                  >
                    <div class="help-search-title">{result.title}</div>
                    <div class="help-search-snippet">{result.category}</div>
                  </div>
                  <div
                    :if={@search_results == [] && @search_query != ""}
                    class="help-no-results"
                  >
                    No results found.
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Content pane --%>
          <div class="help-content" data-testid="help-content-pane" phx-click="help_content_click">
            <%= if @selected_topic do %>
              {raw(@selected_topic.content)}
            <% else %>
              <p class="help-no-topic">
                Select a topic from the navigation pane to get started.
              </p>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
