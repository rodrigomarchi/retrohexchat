defmodule RetroHexChatWeb.App.GroupCallSummary do
  @moduledoc """
  The read-model of a channel call, for readers who are not in it.

  A call has two audiences. Someone inside it needs media, layout, focus and a
  signalling token; someone who is only looking at the channel needs one thing
  — is there a call, and who is in it. This module answers the second question
  and nothing else, which is why it takes no socket and decides no policy.

  The summary reaches a reader from three places: `RetroHexChat.GroupCall`'s
  room server, a PubSub broadcast with string keys, and the database row alone
  when the room server has nothing to say. `normalize/2` is what makes those
  three read the same, and it is idempotent — the reconnect path feeds an
  already normalised summary back through it.
  """

  alias RetroHexChat.GroupCall
  alias RetroHexChatWeb.App.GroupCallShape
  alias RetroHexChatWeb.App.GroupCallStats

  @doc """
  The live summary of the call open in `channel_name`, or `nil` when there is
  none.

  A room whose server cannot answer still counts as a call: the row is the
  authority on whether the room exists, and an empty roster reads correctly.
  """
  @spec fetch(String.t()) :: map() | nil
  def fetch(channel_name) when is_binary(channel_name) do
    case GroupCall.active_room_for_channel(channel_name) do
      nil -> nil
      room -> summary_for(room)
    end
  end

  def fetch(_channel_name), do: nil

  @doc """
  The shape every reader of a channel call walks, whatever the source spelled.

  `nil` becomes the shape of a room that exists with nobody in it rather than
  an absent value, because the tab bar and the badge render either way.
  """
  @spec normalize(map() | nil, String.t()) :: map()
  def normalize(nil, channel_name) do
    %{
      room: empty_room(channel_name),
      participants: [],
      pending_participants: [],
      tracks: [],
      server_stats: GroupCallStats.empty_server(),
      participant_quality: GroupCallShape.empty_participant_quality()
    }
  end

  def normalize(summary, channel_name) when is_map(summary) do
    room = normalize_room(summary, channel_name)

    %{
      room: %{room | channel_name: room.channel_name || channel_name},
      participants:
        GroupCallShape.normalize_participants(GroupCallShape.value(summary, :participants)),
      pending_participants:
        GroupCallShape.normalize_participants(
          GroupCallShape.value(summary, :pending_participants)
        ),
      tracks: GroupCallShape.normalize_tracks(GroupCallShape.value(summary, :tracks)),
      server_stats:
        GroupCallShape.normalize_server_stats(GroupCallShape.value(summary, :server_stats)),
      participant_quality:
        GroupCallShape.value(summary, :participant_quality) ||
          GroupCallShape.empty_participant_quality()
    }
  end

  defp summary_for(room) do
    case GroupCall.get_summary(room.token) do
      {:ok, summary} -> summary
      {:error, _reason} -> row_only_summary(room)
    end
  end

  defp row_only_summary(room) do
    %{
      room: %{
        id: room.id,
        token: room.token,
        channel_name: room.channel_name,
        status: room.status,
        max_participants: room.max_participants,
        metadata: room.metadata,
        inserted_at: room.inserted_at,
        opened_at: room.opened_at,
        activated_at: room.activated_at
      },
      participants: [],
      pending_participants: [],
      tracks: [],
      server_stats: GroupCallStats.empty_server()
    }
  end

  # A broadcast that lost its nesting still describes a room: the fields are
  # simply one level up.
  defp normalize_room(summary, channel_name) do
    case GroupCallShape.normalize_room(GroupCallShape.value(summary, :room)) do
      nil ->
        %{
          empty_room(channel_name)
          | token: GroupCallShape.value(summary, :token),
            status: GroupCallShape.value(summary, :status) || "open",
            max_participants: GroupCallShape.value(summary, :max_participants),
            metadata: GroupCallShape.value(summary, :metadata) || %{}
        }

      room ->
        room
    end
  end

  defp empty_room(channel_name) do
    %{
      id: nil,
      token: nil,
      channel_name: channel_name,
      status: "open",
      max_participants: nil,
      metadata: %{},
      inserted_at: nil,
      opened_at: nil,
      activated_at: nil
    }
  end
end
