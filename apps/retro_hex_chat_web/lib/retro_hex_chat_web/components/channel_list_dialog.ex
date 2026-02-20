defmodule RetroHexChatWeb.Components.ChannelListDialog do
  @moduledoc """
  Channel List dialog (inline modal) showing all active channels
  with name, topic, user count, and join functionality.
  """
  use Phoenix.Component

  attr :visible, :boolean, default: false
  attr :channels, :list, default: []
  attr :filtered, :list, default: []
  attr :search, :string, default: ""
  attr :loading, :boolean, default: true
  attr :channel_count, :integer, default: 0

  @spec channel_list_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def channel_list_dialog(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      data-testid="channel-list-dialog"
    >
      <div class="window dialog-window--450">
        <div class="title-bar">
          <div class="title-bar-text">Channel List</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="toggle_channel_list"></button>
          </div>
        </div>
        <div class="window-body dialog-body">
          <div class="u-mb-8">
            <input
              type="text"
              placeholder="Search channels..."
              value={@search}
              phx-keyup="channel_list_filter"
              phx-debounce="200"
              name="search"
              class="u-w-full"
              data-testid="channel-list-search"
            />
          </div>
          <div :if={@loading} class="loading-spinner" data-testid="channel-list-loading">
            <div class="loading-spinner__bar" role="progressbar"></div>
            <span class="loading-spinner__text">
              Fetching channels... {@channel_count} found
            </span>
          </div>
          <div :if={!@loading} class="channel-list-scroll">
            <table class="table-standard">
              <thead>
                <tr>
                  <th>Channel</th>
                  <th>Topic</th>
                  <th class="u-text-right">Users</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr :for={ch <- @filtered}>
                  <td>{ch.name}</td>
                  <td class="u-text-muted">{ch.topic || ""}</td>
                  <td class="u-text-right">{ch.user_count}</td>
                  <td>
                    <button
                      type="button"
                      phx-click="channel_list_join"
                      phx-value-channel={ch.name}
                      class="btn-sm"
                    >
                      Join
                    </button>
                  </td>
                </tr>
                <tr :if={@filtered == []}>
                  <td colspan="4" class="table-empty">
                    No channels found
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div class="button-row u-mt-12">
            <button type="button" phx-click="toggle_channel_list">Close</button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
