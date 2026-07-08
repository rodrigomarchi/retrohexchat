defmodule RetroHexChat.Lobby.Policy do
  @moduledoc """
  Authorization rules for P2P lobby operations, checked against the
  `lobby_sessions` table.
  """
  use Gettext, backend: RetroHexChat.Gettext

  import Ecto.Query

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
      from(e in "ignore_list_entries",
        where:
          e.ignore_type in ^@session_blocking_ignore_types and
            ((e.owner_nickname == ^creator_nick and e.ignored_nickname == ^peer_nick) or
               (e.owner_nickname == ^peer_nick and e.ignored_nickname == ^creator_nick)),
        select: true
      )
      |> Repo.exists?()

    if blocked do
      {:error, dgettext("lobby", "User not available")}
    else
      :ok
    end
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
