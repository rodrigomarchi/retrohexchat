defmodule RetroHexChat.GroupCall.Policy do
  @moduledoc """
  Authorization rules for channel-scoped group calls.

  Group calls deliberately reuse channel membership and moderation authority.
  There is no separate call host role in the MVP.
  """
  use Gettext, backend: RetroHexChat.Gettext

  import Ecto.Query

  alias RetroHexChat.Channels.Membership
  alias RetroHexChat.Channels.Policy, as: ChannelPolicy
  alias RetroHexChat.GroupCall.Queries
  alias RetroHexChat.GroupCall.Schema.Room
  alias RetroHexChat.Repo

  @moderator_roles [:owner, :operator, :half_operator]

  @spec can_create_channel_call?(integer() | nil, String.t(), String.t(), Membership.t()) ::
          :ok | {:error, String.t()}
  def can_create_channel_call?(registered_nick_id, nickname, channel_name, membership) do
    with :ok <- check_present(channel_name),
         :ok <- check_registered(registered_nick_id),
         :ok <- check_member(membership, nickname),
         :ok <- check_no_active_room(channel_name) do
      :ok
    end
  end

  @spec can_join?(integer() | nil, String.t(), Room.t(), Membership.t()) ::
          :ok | {:error, String.t()}
  def can_join?(registered_nick_id, nickname, room, membership) do
    with :ok <- check_registered(registered_nick_id),
         :ok <- check_member(membership, nickname),
         :ok <- check_not_terminal(room),
         :ok <- check_not_locked(room, membership, nickname) do
      :ok
    end
  end

  @spec can_close?(String.t(), Room.t(), Membership.t()) :: :ok | {:error, String.t()}
  def can_close?(nickname, room, membership) do
    with :ok <- check_not_terminal(room),
         :ok <- check_moderator(membership, nickname) do
      :ok
    end
  end

  @spec can_kick_participant?(Membership.t(), String.t(), String.t()) ::
          :ok | {:error, String.t()}
  def can_kick_participant?(membership, actor_nickname, target_nickname) do
    ChannelPolicy.can_kick?(membership, actor_nickname, target_nickname)
  end

  @spec can_moderate_media?(Membership.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def can_moderate_media?(membership, actor_nickname, target_nickname) do
    can_kick_participant?(membership, actor_nickname, target_nickname)
  end

  defp check_present(value) when is_binary(value) do
    if String.trim(value) == "" do
      {:error, dgettext("group_call", "Channel is required")}
    else
      :ok
    end
  end

  defp check_present(_), do: {:error, dgettext("group_call", "Channel is required")}

  defp check_registered(nil),
    do: {:error, dgettext("group_call", "You must be registered to use group calls")}

  defp check_registered(user_id) do
    exists =
      from(r in "registered_nicks", where: r.id == ^user_id, select: true)
      |> Repo.exists?()

    if exists do
      :ok
    else
      {:error, dgettext("group_call", "You must be registered to use group calls")}
    end
  end

  defp check_member(membership, nickname) do
    if Membership.member?(membership, nickname) do
      :ok
    else
      {:error, dgettext("group_call", "You are not in this channel")}
    end
  end

  defp check_no_active_room(channel_name) do
    if Queries.active_room_exists?(channel_name) do
      {:error, dgettext("group_call", "This channel already has an active group call")}
    else
      :ok
    end
  end

  defp check_not_terminal(room) do
    if Room.terminal?(room.status) do
      {:error, dgettext("group_call", "Group call is no longer active")}
    else
      :ok
    end
  end

  defp check_not_locked(room, membership, nickname) do
    if locked?(room) do
      check_moderator(membership, nickname)
      |> case do
        :ok -> :ok
        {:error, _reason} -> {:error, dgettext("group_call", "Group call is locked")}
      end
    else
      :ok
    end
  end

  defp locked?(%{metadata: metadata}) when is_map(metadata) do
    Map.get(metadata, "locked", Map.get(metadata, :locked)) == true or
      Map.get(metadata, "admission_locked", Map.get(metadata, :admission_locked)) == true
  end

  defp locked?(_room), do: false

  defp check_moderator(membership, nickname) do
    case Membership.role(membership, nickname) do
      {:ok, role} when role in @moderator_roles ->
        :ok

      {:ok, _role} ->
        {:error, dgettext("group_call", "Insufficient privileges")}

      {:error, :not_member} ->
        {:error, dgettext("group_call", "Insufficient privileges")}
    end
  end
end
