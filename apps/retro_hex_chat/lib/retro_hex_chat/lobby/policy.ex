defmodule RetroHexChat.Lobby.Policy do
  @moduledoc """
  Authorization rules for P2P lobby operations, checked against the
  `lobby_sessions` table.
  """
  use Gettext, backend: RetroHexChat.Gettext

  import Ecto.Query

  alias RetroHexChat.Chat.PreferencePersistence.Request
  alias RetroHexChat.Lobby.Queries
  alias RetroHexChat.Lobby.Schema.Session
  alias RetroHexChat.Repo

  @session_blocking_ignore_types ~w(all invites)

  @spec can_create?(integer(), integer()) :: :ok | {:error, String.t()}
  def can_create?(creator_id, peer_id) do
    with :ok <- check_not_self(creator_id, peer_id),
         :ok <- check_registered(creator_id, :creator),
         :ok <- check_registered(peer_id, :peer),
         :ok <- check_no_active_session(creator_id, peer_id),
         :ok <- check_no_block(creator_id, peer_id) do
      :ok
    end
  end

  @spec can_join?(integer(), Session.t()) :: :ok | {:error, String.t()}
  def can_join?(user_id, session) do
    with :ok <- check_participant(user_id, session),
         :ok <- check_not_terminal(session) do
      :ok
    end
  end

  @spec can_close?(integer(), Session.t()) :: :ok | {:error, String.t()}
  def can_close?(user_id, session) do
    with :ok <- check_participant(user_id, session),
         :ok <- check_not_terminal(session) do
      :ok
    end
  end

  @spec can_decline?(integer(), Session.t()) :: :ok | {:error, String.t()}
  def can_decline?(user_id, session) do
    with :ok <- check_role(user_id, session, :peer),
         :ok <- check_pending(session) do
      :ok
    end
  end

  @spec can_cancel_invite?(integer(), Session.t()) :: :ok | {:error, String.t()}
  def can_cancel_invite?(user_id, session) do
    with :ok <- check_role(user_id, session, :creator),
         :ok <- check_pending(session) do
      :ok
    end
  end

  defp check_not_self(id, id),
    do: {:error, dgettext("lobby", "Cannot create a session with yourself")}

  defp check_not_self(_, _), do: :ok

  defp check_registered(user_id, role) do
    exists =
      from(r in "registered_nicks", where: r.id == ^user_id, select: true)
      |> Repo.exists?()

    if exists do
      :ok
    else
      case role do
        :creator -> {:error, dgettext("lobby", "You must be registered to use the lobby")}
        :peer -> {:error, dgettext("lobby", "Target user must be registered")}
      end
    end
  end

  defp check_no_active_session(creator_id, peer_id) do
    if Queries.active_session_exists?(creator_id, peer_id) do
      {:error, dgettext("lobby", "An active lobby already exists with this user")}
    else
      :ok
    end
  end

  defp check_no_block(creator_id, peer_id) do
    creator_nick = get_nickname(creator_id)
    peer_nick = get_nickname(peer_id)

    blocked =
      ignore_blocks_lobby?(creator_nick, peer_nick) or
        ignore_blocks_lobby?(peer_nick, creator_nick)

    if blocked do
      {:error, dgettext("lobby", "User not available")}
    else
      :ok
    end
  end

  defp ignore_blocks_lobby?(owner_nick, ignored_nick)
       when is_binary(owner_nick) and is_binary(ignored_nick) do
    case pending_ignore_payload(owner_nick) do
      {:ok, payload} -> payload_blocks_lobby?(payload, ignored_nick)
      :not_found -> persisted_ignore_blocks_lobby?(owner_nick, ignored_nick)
    end
  end

  defp ignore_blocks_lobby?(_owner_nick, _ignored_nick), do: false

  defp pending_ignore_payload(owner_nick) do
    Request
    |> where([request], request.owner_nickname == ^owner_nick)
    |> where([request], request.preference_type == "ignore_list")
    |> where([request], request.applied_revision < request.revision)
    |> select([request], request.payload)
    |> Repo.one()
    |> case do
      nil -> :not_found
      payload -> {:ok, payload}
    end
  end

  defp payload_blocks_lobby?(payload, ignored_nick) when is_map(payload) do
    now = DateTime.utc_now()
    ignored_downcased = String.downcase(ignored_nick)

    payload
    |> payload_entries()
    |> Enum.any?(fn entry ->
      entry_nickname_matches?(entry, ignored_downcased) and
        entry_blocks_lobby?(entry) and
        not entry_expired?(entry, now)
    end)
  end

  defp payload_blocks_lobby?(_payload, _ignored_nick), do: false

  defp payload_entries(payload) do
    case Map.get(payload, "entries") || Map.get(payload, :entries) do
      entries when is_list(entries) -> entries
      _ -> []
    end
  end

  defp entry_nickname_matches?(entry, ignored_downcased) when is_map(entry) do
    entry
    |> entry_value(:nickname)
    |> case do
      nickname when is_binary(nickname) -> String.downcase(nickname) == ignored_downcased
      _ -> false
    end
  end

  defp entry_nickname_matches?(_entry, _ignored_downcased), do: false

  defp entry_blocks_lobby?(entry) when is_map(entry) do
    entry
    |> entry_value(:ignore_type)
    |> to_string()
    |> then(&(&1 in @session_blocking_ignore_types))
  end

  defp entry_blocks_lobby?(_entry), do: false

  defp entry_expired?(entry, now) when is_map(entry) do
    entry
    |> entry_value(:expires_at)
    |> expired_at?(now)
  end

  defp entry_expired?(_entry, _now), do: false

  defp entry_value(entry, key), do: Map.get(entry, Atom.to_string(key)) || Map.get(entry, key)

  defp expired_at?(nil, _now), do: false
  defp expired_at?("", _now), do: false

  defp expired_at?(%DateTime{} = expires_at, now),
    do: DateTime.compare(expires_at, now) != :gt

  defp expired_at?(expires_at, now) when is_binary(expires_at) do
    case DateTime.from_iso8601(expires_at) do
      {:ok, parsed, _offset} -> expired_at?(parsed, now)
      _ -> false
    end
  end

  defp expired_at?(_expires_at, _now), do: false

  defp persisted_ignore_blocks_lobby?(owner_nick, ignored_nick) do
    now = DateTime.utc_now()

    from(e in "ignore_list_entries",
      where:
        e.ignore_type in ^@session_blocking_ignore_types and
          e.owner_nickname == ^owner_nick and
          e.ignored_nickname == ^ignored_nick and
          (is_nil(e.expires_at) or e.expires_at > ^now),
      select: true
    )
    |> Repo.exists?()
  end

  defp check_participant(user_id, session) do
    if user_id == session.creator_id or user_id == session.peer_id do
      :ok
    else
      {:error, dgettext("lobby", "You are not a participant in this lobby")}
    end
  end

  defp check_role(user_id, session, :peer) do
    if user_id == session.peer_id do
      :ok
    else
      {:error, dgettext("lobby", "Only the invited user can decline")}
    end
  end

  defp check_role(user_id, session, :creator) do
    if user_id == session.creator_id do
      :ok
    else
      {:error, dgettext("lobby", "Only the inviter can cancel the invite")}
    end
  end

  defp check_pending(%{status: "pending"}), do: :ok

  defp check_pending(_session),
    do: {:error, dgettext("lobby", "Invite is no longer pending")}

  defp check_not_terminal(session) do
    if Session.terminal?(session.status) do
      {:error, dgettext("lobby", "Lobby is no longer active")}
    else
      :ok
    end
  end

  defp get_nickname(user_id) do
    from(r in "registered_nicks", where: r.id == ^user_id, select: r.nickname)
    |> Repo.one()
  end
end
