defmodule RetroHexChat.Lobby do
  @moduledoc """
  Public API for the P2P lobby bounded context.

  A lobby is a single *persistent* P2P connection between two registered users
  that hosts audio, video, file transfer and games **concurrently**. All
  external callers use this module; WebRTC signal validation and ICE server
  configuration are reused from `RetroHexChat.P2P`.
  """

  alias RetroHexChat.Lobby.{Policy, Queries, Service, SessionServer}
  alias RetroHexChat.Lobby.Schema.Session
  alias RetroHexChat.Services.Queries, as: ServiceQueries

  @typedoc """
  Resolved, presentation-ready summary of a lobby session for a chat invite
  card. Nicks are resolved from `creator_id`/`peer_id`; timestamps are raw so
  the renderer can localize them to the viewer's timezone.
  """
  @type summary :: %{
          kind: :lobby,
          token: String.t(),
          status: String.t(),
          terminal?: boolean(),
          created_by: String.t() | nil,
          peer: String.t() | nil,
          created_at: DateTime.t() | nil,
          accepted_at: DateTime.t() | nil,
          connected_at: DateTime.t() | nil,
          closed_at: DateTime.t() | nil,
          closed_reason: String.t() | nil,
          duration_seconds: integer() | nil
        }

  @typedoc "What one pass of the open-lobby sweep closed, and what it left."
  @type expiry_summary :: %{
          candidates: non_neg_integer(),
          expired: non_neg_integer(),
          skipped: non_neg_integer(),
          remaining: non_neg_integer()
        }

  @spec create_session(integer(), integer()) ::
          {:ok, %{session: Session.t(), token: String.t()}} | {:error, String.t()}
  defdelegate create_session(creator_id, peer_id), to: Service

  @doc """
  Creates a lobby with no peer named — the match link of wave 5.

  A session used to be born pointing at one person, so a link to a match had
  nowhere to point. This is the other half: a lobby with a creator, an empty
  seat and a deadline.
  """
  @spec create_open_session(integer(), keyword()) ::
          {:ok, %{session: Session.t(), token: String.t()}} | {:error, String.t()}
  defdelegate create_open_session(creator_id, opts \\ []), to: Service

  @doc """
  Takes the empty seat of an open lobby — one conditional write, never a check.

  `{:error, :already_claimed}` is the answer for a seat somebody else took, a
  lobby that expired, and one that was never open: from the claimer's side they
  are the same fact.
  """
  @spec claim_open_session(String.t(), integer()) ::
          {:ok, Session.t()} | {:error, String.t() | :already_claimed}
  defdelegate claim_open_session(token, claimer_id), to: Service

  @doc "Whether `user_id` may take the empty seat of `session`."
  @spec can_claim?(integer(), Session.t()) :: :ok | {:error, String.t()}
  defdelegate can_claim?(user_id, session), to: Policy

  @doc """
  The game a session was created for, if it was created for one.

  Read from the session rather than from the address that led here: a match is
  a match because of what it was made for, not because of the path somebody
  typed.
  """
  @spec match_game_id(Session.t()) :: String.t() | nil
  def match_game_id(%Session{metadata: metadata}) when is_map(metadata) do
    case Map.get(metadata, "game_id") do
      game_id when is_binary(game_id) and game_id != "" -> game_id
      _absent -> nil
    end
  end

  def match_game_id(_session), do: nil

  @doc "Whether `session` is a match link with its seat still empty."
  @spec open_session?(Session.t()) :: boolean()
  def open_session?(%Session{status: "open", peer_id: nil}), do: true
  def open_session?(_session), do: false

  @spec can_create_session?(integer(), integer()) :: :ok | {:error, String.t()}
  defdelegate can_create_session?(creator_id, peer_id), to: Service

  @doc """
  Takes the caller's seat in the session, monitoring it as that side's live
  connection.

  `takeover: true` says the caller is replacing a page of this same person that
  is still holding the seat — a second tab of the same session. Without it, a
  seat that is still held answers `{:error, :already_joined}`.
  """
  @spec join_session(String.t(), integer(), keyword()) ::
          :ok | {:error, String.t() | :already_joined}
  defdelegate join_session(token, user_id, opts \\ []), to: Service

  @spec close_session(String.t(), integer(), String.t()) :: :ok | {:error, String.t()}
  defdelegate close_session(token, user_id, reason), to: Service

  @spec decline_session(String.t(), integer()) :: :ok | {:error, String.t()}
  defdelegate decline_session(token, user_id), to: Service

  @spec cancel_invite(String.t(), integer()) :: :ok | {:error, String.t()}
  defdelegate cancel_invite(token, user_id), to: Service

  @spec close_sessions_between(integer(), integer()) :: :ok
  defdelegate close_sessions_between(user_a_id, user_b_id), to: Service

  @spec propose_game(String.t(), integer(), String.t()) :: :ok | {:error, atom()}
  defdelegate propose_game(token, user_id, game_id), to: Service

  @spec respond_game(String.t(), integer(), boolean()) :: :ok | {:error, atom()}
  defdelegate respond_game(token, user_id, accepted?), to: Service

  @spec get_session(String.t()) :: {:ok, Session.t()} | {:error, :not_found}
  def get_session(token) do
    case Queries.get_session_by_token(token) do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end

  @doc """
  Resolves a lobby session into a `t:summary/0` for transcript summaries
  (creator/peer nicks, lifecycle timestamps, duration and close reason).
  """
  @spec session_summary(String.t()) :: {:ok, summary()} | {:error, :not_found}
  def session_summary(token) do
    case Queries.get_session_by_token(token) do
      nil ->
        {:error, :not_found}

      session ->
        {:ok,
         %{
           kind: :lobby,
           token: session.token,
           status: session.status,
           terminal?: Session.terminal?(session.status),
           created_by: ServiceQueries.get_nickname_by_id(session.creator_id),
           peer: ServiceQueries.get_nickname_by_id(session.peer_id),
           created_at: session.inserted_at,
           accepted_at: session.accepted_at,
           connected_at: session.connected_at,
           closed_at: session.closed_at,
           closed_reason: session.closed_reason,
           duration_seconds: session.duration_seconds
         }}
    end
  end

  @spec transition_status(String.t(), atom()) :: :ok | {:error, String.t()}
  defdelegate transition_status(token, new_status), to: SessionServer, as: :transition

  @spec session_info(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate session_info(token), to: SessionServer, as: :get_state

  @spec signaling_released?(String.t()) :: boolean()
  defdelegate signaling_released?(token), to: SessionServer

  @spec leave(String.t(), integer()) :: :ok
  defdelegate leave(token, user_id), to: SessionServer

  @spec record_activity(String.t()) :: :ok
  defdelegate record_activity(token), to: SessionServer

  @doc """
  The user's most recently updated non-terminal session, if any — the entry
  point for re-hydrating a P2P session after a LiveView reconnect, where the
  client no longer carries the token.
  """
  @spec active_session_for_user(integer()) :: Session.t() | nil
  def active_session_for_user(user_id) do
    user_id |> active_sessions_for_user() |> List.first()
  end

  @doc """
  Every non-terminal session this user is part of, newest first.

  One person can be in several at once — each with a different peer, each at
  its own address — so a reader that draws a badge per conversation asks for
  all of them rather than for the latest.

  Match links this person has minted are excluded: nobody has taken the seat,
  so there is no conversation for it to belong to.
  """
  @spec active_sessions_for_user(integer()) :: [Session.t()]
  defdelegate active_sessions_for_user(user_id), to: Queries

  @doc """
  Returns the most recent non-terminal P2P session between two registered nicks.

  Used by the chat PM chrome to expose pending requests without depending on
  the invite message currently being visible in the transcript.
  """
  @spec active_session_between_nicks(String.t(), String.t()) :: Session.t() | nil
  def active_session_between_nicks(nick_a, nick_b)
      when is_binary(nick_a) and is_binary(nick_b) do
    with %{id: user_a_id} <- ServiceQueries.find_by_nickname(nick_a),
         %{id: user_b_id} <- ServiceQueries.find_by_nickname(nick_b) do
      user_a_id
      |> Queries.active_sessions_between(user_b_id)
      |> List.first()
    else
      _ -> nil
    end
  end

  def active_session_between_nicks(_nick_a, _nick_b), do: nil

  @doc """
  Closes every open lobby whose window has passed, and says what it did.

  The sweep is the mitigation, not a tidy-up: an unclaimed match link is a seat
  anybody holding the address can take, so the deadline is what bounds how long
  that is true. Re-stating the condition inside the write is what keeps it from
  closing a match two people just walked into.
  """
  @spec expire_open_sessions(keyword()) :: {:ok, expiry_summary()} | {:error, term()}
  def expire_open_sessions(opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    limit = Keyword.get(opts, :limit, 100)

    candidates = Queries.list_expired_open_sessions(now, limit: limit)
    initial = %{candidates: length(candidates), expired: 0, skipped: 0}

    # A row somebody claimed between the listing and the write is skipped; a
    # write that failed is not, because a sweep that reports "ok" over a broken
    # database is one nothing will ever retry.
    candidates
    |> Enum.reduce_while({:ok, initial}, fn session, {:ok, acc} ->
      case Queries.expire_open_session(session, now) do
        {:ok, :expired} -> {:cont, {:ok, Map.update!(acc, :expired, &(&1 + 1))}}
        {:ok, :skipped} -> {:cont, {:ok, Map.update!(acc, :skipped, &(&1 + 1))}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, summary} ->
        {:ok, Map.put(summary, :remaining, Queries.expired_open_session_count(now))}

      {:error, _reason} = error ->
        error
    end
  end

  @spec mark_webrtc_ready(String.t(), integer()) :: :ok | {:error, atom()}
  defdelegate mark_webrtc_ready(token, user_id), to: SessionServer

  @spec record_signaling_event(String.t(), integer(), String.t(), map()) :: :ok | {:error, atom()}
  defdelegate record_signaling_event(token, user_id, event, payload), to: SessionServer

  @spec signaling_replay(String.t(), integer()) :: {:ok, [map()]} | {:error, atom()}
  defdelegate signaling_replay(token, user_id), to: SessionServer

  @spec set_media(String.t(), integer(), boolean(), boolean()) :: :ok | {:error, atom()}
  defdelegate set_media(token, user_id, audio?, video?), to: SessionServer

  @spec end_game(String.t(), integer()) :: :ok | {:error, atom()}
  defdelegate end_game(token, user_id), to: SessionServer

  @spec finish_game(String.t(), integer(), map()) :: :ok | {:error, atom()}
  defdelegate finish_game(token, user_id, result), to: SessionServer
end
