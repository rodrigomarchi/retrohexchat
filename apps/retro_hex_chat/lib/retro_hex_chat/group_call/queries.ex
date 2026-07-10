defmodule RetroHexChat.GroupCall.Queries do
  @moduledoc """
  Database queries for persisted group call lifecycle records.
  """

  import Ecto.Query

  alias RetroHexChat.GroupCall.Schema.{Participant, Room, Track}
  alias RetroHexChat.Repo

  @room_terminal_statuses Room.terminal_statuses()
  @participant_terminal_statuses Participant.terminal_statuses()
  @track_terminal_statuses Track.terminal_statuses()

  @spec insert_room(map()) :: {:ok, Room.t()} | {:error, Ecto.Changeset.t()}
  def insert_room(attrs) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end

  @spec get_room(integer()) :: Room.t() | nil
  def get_room(id), do: Repo.get(Room, id)

  @spec get_room_by_token(String.t()) :: Room.t() | nil
  def get_room_by_token(token), do: Repo.get_by(Room, token: token)

  @spec update_room_status(Room.t(), String.t(), map()) ::
          {:ok, Room.t()} | {:error, Ecto.Changeset.t()}
  def update_room_status(room, new_status, extra_attrs \\ %{}) do
    attrs = Map.merge(extra_attrs, %{status: new_status})

    room
    |> Room.status_changeset(attrs)
    |> Repo.update()
  end

  @spec active_room_exists?(String.t()) :: boolean()
  def active_room_exists?(channel_name) do
    Room
    |> where([r], r.channel_name == ^channel_name)
    |> where([r], r.status not in ^@room_terminal_statuses)
    |> Repo.exists?()
  end

  @spec get_active_room_for_channel(String.t()) :: Room.t() | nil
  def get_active_room_for_channel(channel_name) do
    Room
    |> where([r], r.channel_name == ^channel_name)
    |> where([r], r.status not in ^@room_terminal_statuses)
    |> order_by([r], desc: r.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @spec list_stale_rooms(DateTime.t()) :: [Room.t()]
  def list_stale_rooms(before_datetime) do
    Room
    |> where([r], r.status not in ^@room_terminal_statuses)
    |> where([r], r.updated_at < ^before_datetime)
    |> Repo.all()
  end

  @spec expire_room(Room.t()) :: {:ok, Room.t()} | {:error, Ecto.Changeset.t()}
  def expire_room(room) do
    update_room_status(room, "expired", %{
      closed_at: DateTime.utc_now(),
      closed_reason: "stale_cleanup"
    })
  end

  @spec insert_participant(map()) :: {:ok, Participant.t()} | {:error, Ecto.Changeset.t()}
  def insert_participant(attrs) do
    %Participant{}
    |> Participant.changeset(attrs)
    |> Repo.insert()
  end

  @spec get_participant(integer()) :: Participant.t() | nil
  def get_participant(id), do: Repo.get(Participant, id)

  @spec get_active_participant(integer(), String.t()) :: Participant.t() | nil
  def get_active_participant(room_id, nickname) do
    normalized_nickname = String.downcase(nickname)

    Participant
    |> where([p], p.room_id == ^room_id)
    |> where([p], p.normalized_nickname == ^normalized_nickname)
    |> where([p], p.status not in ^@participant_terminal_statuses)
    |> order_by([p], desc: p.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @spec list_participants(integer()) :: [Participant.t()]
  def list_participants(room_id) do
    Participant
    |> where([p], p.room_id == ^room_id)
    |> order_by([p], asc: p.inserted_at)
    |> Repo.all()
  end

  @spec list_active_participants(integer()) :: [Participant.t()]
  def list_active_participants(room_id) do
    Participant
    |> where([p], p.room_id == ^room_id)
    |> where([p], p.status not in ^@participant_terminal_statuses)
    |> order_by([p], asc: p.inserted_at)
    |> Repo.all()
  end

  @spec update_participant_status(Participant.t(), String.t(), map()) ::
          {:ok, Participant.t()} | {:error, Ecto.Changeset.t()}
  def update_participant_status(participant, new_status, extra_attrs \\ %{}) do
    attrs = Map.merge(extra_attrs, %{status: new_status})

    participant
    |> Participant.status_changeset(attrs)
    |> Repo.update()
  end

  @spec insert_track(map()) :: {:ok, Track.t()} | {:error, Ecto.Changeset.t()}
  def insert_track(attrs) do
    %Track{}
    |> Track.changeset(attrs)
    |> Repo.insert()
  end

  @spec get_track(integer()) :: Track.t() | nil
  def get_track(id), do: Repo.get(Track, id)

  @spec get_track_by_webrtc_id(integer(), String.t()) :: Track.t() | nil
  def get_track_by_webrtc_id(room_id, webrtc_track_id) do
    Repo.get_by(Track, room_id: room_id, webrtc_track_id: webrtc_track_id)
  end

  @spec get_active_track_by_source(integer(), integer(), String.t(), String.t()) ::
          Track.t() | nil
  def get_active_track_by_source(room_id, participant_id, kind, source) do
    Track
    |> where([t], t.room_id == ^room_id)
    |> where([t], t.participant_id == ^participant_id)
    |> where([t], t.kind == ^kind)
    |> where([t], t.source == ^source)
    |> where([t], t.status not in ^@track_terminal_statuses)
    |> order_by([t], desc: t.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @spec list_tracks(integer()) :: [Track.t()]
  def list_tracks(room_id) do
    Track
    |> where([t], t.room_id == ^room_id)
    |> order_by([t], asc: t.inserted_at)
    |> Repo.all()
  end

  @spec list_active_tracks(integer()) :: [Track.t()]
  def list_active_tracks(room_id) do
    Track
    |> where([t], t.room_id == ^room_id)
    |> where([t], t.status not in ^@track_terminal_statuses)
    |> order_by([t], asc: t.inserted_at)
    |> Repo.all()
  end

  @spec update_track_status(Track.t(), String.t(), map()) ::
          {:ok, Track.t()} | {:error, Ecto.Changeset.t()}
  def update_track_status(track, new_status, extra_attrs \\ %{}) do
    attrs = Map.merge(extra_attrs, %{status: new_status})

    track
    |> Track.status_changeset(attrs)
    |> Repo.update()
  end
end
