defmodule RetroHexChat.VirtualSpace.Queries do
  @moduledoc """
  The durable half of a virtual space: gatherings, and who was in them.

  Everything here is written by one process — `VirtualSpace.SessionRecorder` —
  and read by the card in the conversation. The space's own runtime never
  touches this module: a world running a movement step per tick is the last
  place a query belongs, and a `Repo` call inside it would run on a path whose
  caller may already be gone.
  """

  import Ecto.Query

  alias RetroHexChat.Repo
  alias RetroHexChat.StaleRecords
  alias RetroHexChat.VirtualSpace.Schema.Participant
  alias RetroHexChat.VirtualSpace.Schema.Session

  @stale_sessions StaleRecords.new(Session, Session.terminal_statuses())

  @spec insert_session(map()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def insert_session(attrs) do
    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  @spec get_session_by_token(String.t()) :: Session.t() | nil
  def get_session_by_token(token) when is_binary(token),
    do: Repo.get_by(Session, token: token)

  @spec open_session_for_space(String.t()) :: Session.t() | nil
  def open_session_for_space(space_id) when is_binary(space_id) do
    Session
    |> where([s], s.space_id == ^space_id and s.status == "open")
    |> Repo.one()
  end

  @spec list_open_sessions() :: [Session.t()]
  def list_open_sessions do
    Session
    |> where([s], s.status == "open")
    |> Repo.all()
  end

  @spec close_session(Session.t(), String.t()) ::
          {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def close_session(%Session{} = session, reason) do
    now = DateTime.utc_now()

    session
    |> Session.close_changeset(%{status: "closed", closed_at: now, closed_reason: reason})
    |> Repo.update()
  end

  @doc """
  Records somebody walking into a gathering, once however often they walk in.

  The conflict is the point rather than an error to report: the second arrival
  of the same nickname is the same person coming back, and the count on the
  ended card is people, not doors opened.
  """
  @spec record_arrival(integer(), String.t()) :: :ok
  def record_arrival(session_id, nickname) do
    %Participant{}
    |> Participant.changeset(%{
      session_id: session_id,
      nickname: nickname,
      normalized_nickname: String.downcase(nickname),
      joined_at: DateTime.utc_now()
    })
    |> Repo.insert(
      on_conflict: :nothing,
      conflict_target: {:unsafe_fragment, "(session_id, normalized_nickname)"}
    )

    :ok
  end

  @spec count_visitors(integer()) :: non_neg_integer()
  def count_visitors(session_id) do
    Participant
    |> where([p], p.session_id == ^session_id)
    |> Repo.aggregate(:count, :id)
  end

  @spec list_stale_sessions(DateTime.t(), keyword()) :: [Session.t()]
  def list_stale_sessions(before_datetime, opts \\ []),
    do: StaleRecords.list(@stale_sessions, before_datetime, opts)

  @spec stale_session_count(DateTime.t()) :: non_neg_integer()
  def stale_session_count(before_datetime),
    do: StaleRecords.count(@stale_sessions, before_datetime)

  @spec expire_stale_session(Session.t(), DateTime.t()) ::
          {:ok, :expired | :skipped} | {:error, term()}
  def expire_stale_session(%Session{id: id}, before_datetime),
    do: StaleRecords.expire(@stale_sessions, id, before_datetime)
end
