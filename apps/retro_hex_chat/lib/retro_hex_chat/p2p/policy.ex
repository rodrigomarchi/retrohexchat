defmodule RetroHexChat.P2P.Policy do
  @moduledoc """
  Authorization rules for P2P operations.
  """

  import Ecto.Query

  alias RetroHexChat.P2P.Queries
  alias RetroHexChat.P2P.Schema.Session
  alias RetroHexChat.Repo

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

  defp check_not_self(id, id), do: {:error, "Cannot create a session with yourself"}
  defp check_not_self(_, _), do: :ok

  defp check_registered(user_id, role) do
    exists =
      from(r in "registered_nicks", where: r.id == ^user_id, select: true)
      |> Repo.exists?()

    if exists do
      :ok
    else
      case role do
        :creator -> {:error, "You must be registered to use P2P"}
        :peer -> {:error, "Target user must be registered"}
      end
    end
  end

  defp check_no_active_session(creator_id, peer_id) do
    if Queries.active_session_exists?(creator_id, peer_id) do
      {:error, "An active session already exists with this user"}
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
          (e.owner_nickname == ^creator_nick and e.ignored_nickname == ^peer_nick) or
            (e.owner_nickname == ^peer_nick and e.ignored_nickname == ^creator_nick),
        select: true
      )
      |> Repo.exists?()

    if blocked do
      {:error, "Session cannot be created"}
    else
      :ok
    end
  end

  defp check_participant(user_id, session) do
    if user_id == session.creator_id or user_id == session.peer_id do
      :ok
    else
      {:error, "You are not a participant in this session"}
    end
  end

  defp check_not_terminal(session) do
    if Session.terminal?(session.status) do
      {:error, "Session is no longer active"}
    else
      :ok
    end
  end

  defp get_nickname(user_id) do
    from(r in "registered_nicks", where: r.id == ^user_id, select: r.nickname)
    |> Repo.one()
  end
end
