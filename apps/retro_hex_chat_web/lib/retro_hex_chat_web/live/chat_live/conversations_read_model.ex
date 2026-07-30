defmodule RetroHexChatWeb.ChatLive.ConversationsReadModel do
  @moduledoc """
  Read-model helpers for the conversations sidebar.

  This module keeps the sidebar on top of the existing IRC channel directory.
  Popular channels are visible, joinable public channels, not already joined by
  the current session, and sorted by member count.
  """

  import Phoenix.Component, only: [assign: 2]

  alias RetroHexChat.Commands.Autocomplete

  @max_popular_channels 10

  @spec load_popular_channels(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def load_popular_channels(socket) do
    joined = socket.assigns.session.channels

    popular_channels =
      joined
      |> Autocomplete.list_visible_channels()
      |> popular_channels(joined)

    assign(socket, popular_channels: popular_channels)
  end

  @doc """
  Picks the suggestions out of a channel directory listing: the ones this
  session has not joined, public and joinable, most populated first, capped at
  what the sidebar shows.

  The selection lives here, apart from the directory lookup, so it can be
  exercised on a known list instead of on whatever channels happen to be running.
  """
  @spec popular_channels([map()], [String.t()]) :: [map()]
  def popular_channels(channels, joined_names) do
    joined = MapSet.new(joined_names)

    channels
    |> Enum.reject(fn channel -> MapSet.member?(joined, channel.name) end)
    |> Enum.filter(&joinable_public_channel?/1)
    |> Enum.sort_by(& &1.user_count, :desc)
    |> Enum.take(@max_popular_channels)
  end

  defp joinable_public_channel?(%{name: name} = channel) when is_binary(name) do
    String.starts_with?(name, "#") and not Map.get(channel, :invite_only?, false) and
      not keyed?(channel)
  end

  defp joinable_public_channel?(_channel), do: false

  defp keyed?(%{modes: modes}) when is_binary(modes), do: String.contains?(modes, "k")
  defp keyed?(_channel), do: false
end
