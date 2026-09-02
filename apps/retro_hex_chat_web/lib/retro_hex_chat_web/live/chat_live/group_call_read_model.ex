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
  alias RetroHexChatWeb.App.Paths

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
    ordered(channels, summaries(socket))
  end

  def live_summaries(_socket), do: []

  @doc """
  The nicknames in `channel_name`'s conference, or `[]` when it has none.

  The nicklist's marker reads this rather than the room, for the same reason
  the card does: one summary, one answer, and no second reader to drift from
  it.
  """
  @spec participants(Socket.t(), String.t() | nil) :: [String.t()]
  def participants(socket, channel_name) do
    case summary(socket, channel_name) do
      %{participants: participants} when is_list(participants) ->
        participants
        |> Enum.map(&participant_nick/1)
        |> Enum.filter(&is_binary/1)

      _none ->
        []
    end
  end

  defp participant_nick(%{nickname: nickname}), do: nickname
  defp participant_nick(%{"nickname" => nickname}), do: nickname
  defp participant_nick(_participant), do: nil

  @doc """
  The call this person is watching from somewhere else, if there is one.

  The status zone's third shape. A conference can be live, this reader can be
  in it, and the screen showing it is always a tab that is not this one — the
  chat has no window for a call any more, so without this it would draw
  nothing at all about a call its reader is sitting in.

  Derived rather than assigned: both halves are already here. The summaries
  know the room's address and `Live.OpenSurfaces` knows which addresses are
  open, so a third assign would only be a third thing to keep in step. Ordered
  by the session's channel list for the same reason `live_summaries/1` is —
  with two calls open in two tabs, which one the one-line zone names must not
  depend on hashing.
  """
  @spec elsewhere([String.t()], %{String.t() => map()}, MapSet.t(String.t())) ::
          %{channel_name: String.t(), path: String.t()} | nil
  def elsewhere(channels, summaries, %MapSet{} = open_paths)
      when is_list(channels) and is_map(summaries) do
    channels
    |> ordered(summaries)
    |> Enum.find_value(fn {channel_name, summary} ->
      path = call_path(summary)

      if path && MapSet.member?(open_paths, path) do
        %{channel_name: channel_name, path: path}
      end
    end)
  end

  def elsewhere(_channels, _summaries, _open_paths), do: nil

  # Takes the pieces rather than the socket because the caller is a template,
  # and inside one `@socket` carries no assigns at all — a version that read
  # them there would answer "nothing is open" forever, in silence.
  defp ordered(channels, summaries) do
    channels
    |> Enum.filter(&is_binary/1)
    |> Enum.flat_map(fn channel_name ->
      case Map.fetch(summaries, channel_name) do
        {:ok, summary} -> [{channel_name, summary}]
        :error -> []
      end
    end)
  end

  defp call_path(%{room: %{token: token}}) when is_binary(token) and token != "",
    do: Paths.call_path(token)

  defp call_path(_summary), do: nil
end
