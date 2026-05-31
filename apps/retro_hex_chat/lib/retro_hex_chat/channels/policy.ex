defmodule RetroHexChat.Channels.Policy do
  @moduledoc """
  Authorization checks for channel operations.
  """
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Channels.{Masks, Membership, Modes}

  @spec can_join?(
          Modes.t(),
          Membership.t(),
          String.t() | nil,
          String.t() | nil,
          MapSet.t(),
          boolean()
        ) :: :ok | {:error, String.t()}
  def can_join?(
        modes,
        membership,
        password \\ nil,
        nickname \\ nil,
        invite_exceptions \\ MapSet.new(),
        identified \\ false
      ) do
    with :ok <- check_limit(modes, membership),
         :ok <- check_invite(modes, invite_exceptions, nickname),
         :ok <- check_key(modes, password),
         :ok <- check_registered(modes, identified) do
      :ok
    end
  end

  defp check_limit(modes, membership) do
    if Modes.has_limit?(modes) and Membership.count(membership) >= modes.limit,
      do: {:error, dgettext("channels", "Channel is full (+l)")},
      else: :ok
  end

  defp check_invite(modes, invite_exceptions, nickname) do
    if Modes.invite_only?(modes) and not Masks.matches_any?(invite_exceptions, nickname),
      do: {:error, dgettext("channels", "Channel is invite-only (+i)")},
      else: :ok
  end

  defp check_key(modes, password) do
    if Modes.has_key?(modes) and password != modes.key,
      do: {:error, dgettext("channels", "Bad channel key (+k)")},
      else: :ok
  end

  defp check_registered(modes, identified) do
    if Modes.registered_only?(modes) and not identified,
      do: {:error, dgettext("channels", "You must be registered to join this channel")},
      else: :ok
  end

  @spec can_speak?(Modes.t(), Membership.t(), String.t()) :: :ok | {:error, String.t()}
  def can_speak?(modes, membership, nickname) do
    is_member = Membership.member?(membership, nickname)

    cond do
      Modes.no_external?(modes) and not is_member ->
        {:error, dgettext("channels", "Cannot send to channel (no external messages)")}

      Modes.moderated?(modes) ->
        case Membership.role(membership, nickname) do
          {:ok, role} when role in [:owner, :operator, :half_operator, :voiced] ->
            :ok

          {:ok, :regular} ->
            {:error,
             dgettext("channels", "Channel is moderated (+m). You need voice (+v) to speak.")}

          {:error, :not_member} ->
            {:error, dgettext("channels", "You are not in this channel")}
        end

      is_member ->
        :ok

      true ->
        {:error, dgettext("channels", "You are not in this channel")}
    end
  end

  @spec can_change_topic?(Modes.t(), Membership.t(), String.t()) :: :ok | {:error, String.t()}
  def can_change_topic?(modes, membership, nickname) do
    if Modes.topic_locked?(modes) do
      case Membership.role(membership, nickname) do
        {:ok, role} when role in [:owner, :operator] -> :ok
        _ -> {:error, dgettext("channels", "You must be a channel operator to change the topic")}
      end
    else
      if Membership.member?(membership, nickname) do
        :ok
      else
        {:error, dgettext("channels", "You are not in this channel")}
      end
    end
  end

  @spec operator?(Membership.t(), String.t()) :: boolean()
  def operator?(membership, nickname) do
    case Membership.role(membership, nickname) do
      {:ok, role} when role in [:owner, :operator] -> true
      _ -> false
    end
  end

  @spec can_kick?(Membership.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def can_kick?(membership, actor, target) do
    with {:ok, actor_role} <- Membership.role(membership, actor),
         true <- Membership.rank(actor_role) >= Membership.rank(:half_operator) do
      check_kick_target(membership, actor_role, target)
    else
      {:error, :not_member} -> {:error, dgettext("channels", "Insufficient privileges")}
      false -> {:error, dgettext("channels", "Insufficient privileges")}
    end
  end

  defp check_kick_target(membership, actor_role, target) do
    case Membership.role(membership, target) do
      {:ok, target_role} ->
        if Membership.rank(actor_role) > Membership.rank(target_role),
          do: :ok,
          else: {:error, dgettext("channels", "Cannot kick a higher-ranked user")}

      {:error, :not_member} ->
        {:error, "User #{target} is not in channel"}
    end
  end

  @spec can_ban?(Membership.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def can_ban?(membership, actor, target) do
    if actor == target do
      {:error, dgettext("channels", "You cannot ban yourself")}
    else
      with {:ok, actor_role} <- Membership.role(membership, actor),
           true <- actor_role in [:owner, :operator] do
        check_ban_target(membership, actor_role, target)
      else
        {:error, :not_member} -> {:error, dgettext("channels", "Insufficient privileges")}
        false -> {:error, dgettext("channels", "Insufficient privileges")}
      end
    end
  end

  defp check_ban_target(membership, actor_role, target) do
    case Membership.role(membership, target) do
      {:ok, target_role} ->
        if Membership.rank(actor_role) > Membership.rank(target_role),
          do: :ok,
          else: {:error, dgettext("channels", "Cannot ban a user with equal or higher rank")}

      {:error, :not_member} ->
        :ok
    end
  end

  @spec can_set_mode?(Membership.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def can_set_mode?(membership, actor, mode_flag) do
    case Membership.role(membership, actor) do
      {:ok, actor_role} ->
        required_rank = required_rank_for_mode(mode_flag)

        if Membership.rank(actor_role) >= required_rank do
          :ok
        else
          {:error, dgettext("channels", "Insufficient privileges to set channel modes")}
        end

      {:error, :not_member} ->
        {:error, dgettext("channels", "Insufficient privileges to set channel modes")}
    end
  end

  defp required_rank_for_mode(mode_flag) when mode_flag in ~w(q), do: Membership.rank(:owner)

  defp required_rank_for_mode(mode_flag) when mode_flag in ~w(h o),
    do: Membership.rank(:operator)

  defp required_rank_for_mode(mode_flag) when mode_flag in ~w(v),
    do: Membership.rank(:half_operator)

  # Channel flags (+m, +i, +t, +k, +l, +n, +s, +p, +c, +R, +K, +j) require operator+
  defp required_rank_for_mode(_), do: Membership.rank(:operator)
end
