defmodule RetroHexChatWeb.ChatLive.GroupCallReadModel do
  @moduledoc """
  What the chat knows about calls its reader is not in.

  The rule that decides what belongs here: if the datum exists for someone who
  is only looking at the channel, it lives in the chat; if it exists only while
  you are inside the call, it belongs to the call's own surface. The tab bar
  entry, the sidebar badge and the live card in the conversation are all this
  side of that line, and none of them needs media, layout or a signalling
  token.

  Two assigns hold it. `@group_call_channels` answers "does this channel have a
  call" for a render that only needs a badge; `@group_call_channel_summaries`
  carries the roster behind it. Both are read through the accessors here, which
  is what lets a socket that never saw a call render the same as one whose call
  ended.
  """

  import Phoenix.Component, only: [assign: 2]

  alias Phoenix.LiveView.Socket
  alias RetroHexChatWeb.App.GroupCallSummary

  @doc """
  Rebuild the read-model for every channel in the session.

  Called on mount and after a reconnect, where the assigns are gone but the
  rooms are not.
  """
  @spec refresh_all(Socket.t()) :: Socket.t()
  def refresh_all(%{assigns: %{session: %{channels: channels}}} = socket)
      when is_list(channels) do
    channels
    |> Enum.filter(&is_binary/1)
    |> Enum.reduce(socket, &refresh(&2, &1))
  end

  def refresh_all(socket), do: socket

  @doc "Ask the domain whether `channel_name` has a call, and record the answer."
  @spec refresh(Socket.t(), String.t() | nil) :: Socket.t()
  def refresh(socket, channel_name) when is_binary(channel_name) do
    case GroupCallSummary.fetch(channel_name) do
      nil -> mark_inactive(socket, channel_name)
      summary -> mark_active(socket, channel_name, summary)
    end
  end

  def refresh(socket, _channel_name), do: socket

  @doc """
  Record that `channel_name` has a live call.

  A caller holding a fresh broadcast passes it as `summary` rather than paying
  for a round trip the payload already answered.
  """
  @spec mark_active(Socket.t(), String.t() | nil, map() | nil) :: Socket.t()
  def mark_active(socket, channel_name, summary \\ nil)

  def mark_active(socket, channel_name, summary) when is_binary(channel_name) do
    summary =
      GroupCallSummary.normalize(summary || GroupCallSummary.fetch(channel_name), channel_name)

    assign(socket,
      group_call_channels: socket |> channels() |> MapSet.put(channel_name),
      group_call_channel_summaries: socket |> summaries() |> Map.put(channel_name, summary)
    )
  end

  def mark_active(socket, _channel_name, _summary), do: socket

  @doc "Record that `channel_name` no longer has a call."
  @spec mark_inactive(Socket.t(), String.t() | nil) :: Socket.t()
  def mark_inactive(socket, channel_name) when is_binary(channel_name) do
    assign(socket,
      group_call_channels: socket |> channels() |> MapSet.delete(channel_name),
      group_call_channel_summaries: socket |> summaries() |> Map.delete(channel_name)
    )
  end

  def mark_inactive(socket, _channel_name), do: socket

  @doc "The channels whose call is live, for a render that only needs a badge."
  @spec channels(Socket.t()) :: MapSet.t(String.t())
  def channels(socket), do: socket.assigns[:group_call_channels] || MapSet.new()

  @doc "Every live summary, by channel name."
  @spec summaries(Socket.t()) :: %{String.t() => map()}
  def summaries(socket), do: socket.assigns[:group_call_channel_summaries] || %{}

  @doc "The live summary of one channel, or `nil` when it has no call."
  @spec summary(Socket.t(), String.t() | nil) :: map() | nil
  def summary(socket, channel_name), do: Map.get(summaries(socket), channel_name)

  @doc """
  The live summaries in the order the session lists its channels.

  The order is not cosmetic: the reconnect path picks the first channel whose
  call still holds this nickname, and a map's order would make which room you
  rejoin depend on hashing.
  """
  @spec live_summaries(Socket.t()) :: [{String.t(), map()}]
  def live_summaries(%{assigns: %{session: %{channels: channels}}} = socket)
      when is_list(channels) do
    summaries = summaries(socket)

    channels
    |> Enum.filter(&is_binary/1)
    |> Enum.flat_map(fn channel_name ->
      case Map.fetch(summaries, channel_name) do
        {:ok, summary} -> [{channel_name, summary}]
        :error -> []
      end
    end)
  end

  def live_summaries(_socket), do: []
end
