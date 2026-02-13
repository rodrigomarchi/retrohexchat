defmodule RetroHexChatWeb.ChannelListLive do
  @moduledoc """
  Win98-style dialog showing all active channels with name, topic, user count.
  """
  use RetroHexChatWeb, :live_view

  alias RetroHexChat.Channels.{Registry, Server}

  @impl true
  def mount(_params, session, socket) do
    viewer_channels = Map.get(session, "channels", [])
    channels = list_active_channels(viewer_channels)

    {:ok,
     assign(socket,
       channels: channels,
       filtered: channels,
       search: "",
       page_title: "Channel List - RetroHexChat"
     )}
  end

  @impl true
  def handle_event("filter", %{"search" => search}, socket) do
    filtered =
      if search == "" do
        socket.assigns.channels
      else
        term = String.downcase(search)

        Enum.filter(socket.assigns.channels, fn ch ->
          String.contains?(String.downcase(ch.name), term) or
            String.contains?(String.downcase(ch.topic || ""), term)
        end)
      end

    {:noreply, assign(socket, search: search, filtered: filtered)}
  end

  def handle_event("join", %{"channel" => channel_name}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/chat?join=#{channel_name}")}
  end

  def handle_event("close", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/chat")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="connect-dialog" style="min-width: 450px;">
      <div class="window">
        <div class="title-bar">
          <div class="title-bar-text">Channel List</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="close"></button>
          </div>
        </div>
        <div class="window-body" style="padding: 12px;">
          <div style="margin-bottom: 8px;">
            <input
              type="text"
              placeholder="Search channels..."
              value={@search}
              phx-keyup="filter"
              phx-debounce="200"
              name="search"
              style="width: 100%;"
            />
          </div>
          <div style="max-height: 300px; overflow-y: auto;">
            <table style="width: 100%; font-size: 12px;">
              <thead>
                <tr>
                  <th style="text-align: left;">Channel</th>
                  <th style="text-align: left;">Topic</th>
                  <th style="text-align: right;">Users</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr :for={ch <- @filtered}>
                  <td>{ch.name}</td>
                  <td style="color: var(--text-dim);">{ch.topic || ""}</td>
                  <td style="text-align: right;">{ch.user_count}</td>
                  <td>
                    <button
                      type="button"
                      phx-click="join"
                      phx-value-channel={ch.name}
                      style="font-size: 11px;"
                    >
                      Join
                    </button>
                  </td>
                </tr>
                <tr :if={@filtered == []}>
                  <td colspan="4" style="text-align: center; color: var(--text-dim);">
                    No channels found
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div class="button-row" style="margin-top: 12px;">
            <button type="button" phx-click="close">Close</button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @spec list_active_channels([String.t()]) :: [map()]
  defp list_active_channels(viewer_channels) do
    Registry.registry_name()
    |> Elixir.Registry.select([{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.map(fn {channel_name, _pid} ->
      channel_to_list_entry(channel_name, viewer_channels)
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.name)
  end

  defp channel_to_list_entry(channel_name, viewer_channels) do
    case Server.get_state(channel_name) do
      {:ok, state} -> apply_visibility(channel_name, state, channel_name in viewer_channels)
      {:error, _} -> nil
    end
  end

  defp apply_visibility(_channel_name, state, false = _is_member) do
    cond do
      Map.get(state.modes_detail, :secret, false) ->
        nil

      Map.get(state.modes_detail, :private, false) ->
        %{name: "Prv", topic: nil, user_count: state.member_count}

      true ->
        %{name: state.name, topic: state.topic, user_count: state.member_count}
    end
  end

  defp apply_visibility(channel_name, state, true = _is_member) do
    %{name: channel_name, topic: state.topic, user_count: state.member_count}
  end
end
