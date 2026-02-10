defmodule RetroHexChat.Channels.Policy do
  @moduledoc """
  Authorization checks for channel operations.
  """

  alias RetroHexChat.Channels.{Membership, Modes}

  @spec can_join?(Modes.t(), Membership.t(), String.t() | nil, non_neg_integer()) ::
          :ok | {:error, String.t()}
  def can_join?(modes, membership, password \\ nil, _max_channels \\ 10) do
    cond do
      Modes.has_limit?(modes) and Membership.count(membership) >= modes.limit ->
        {:error, "Channel is full (+l)"}

      Modes.invite_only?(modes) ->
        {:error, "Channel is invite-only (+i)"}

      Modes.has_key?(modes) and password != modes.key ->
        {:error, "Bad channel key (+k)"}

      true ->
        :ok
    end
  end

  @spec can_speak?(Modes.t(), Membership.t(), String.t()) :: :ok | {:error, String.t()}
  def can_speak?(modes, membership, nickname) do
    if Modes.moderated?(modes) do
      case Membership.role(membership, nickname) do
        {:ok, :operator} -> :ok
        {:ok, :voiced} -> :ok
        {:ok, :regular} -> {:error, "Channel is moderated (+m). You need voice (+v) to speak."}
        {:error, :not_member} -> {:error, "You are not in this channel"}
      end
    else
      if Membership.member?(membership, nickname) do
        :ok
      else
        {:error, "You are not in this channel"}
      end
    end
  end

  @spec can_change_topic?(Modes.t(), Membership.t(), String.t()) :: :ok | {:error, String.t()}
  def can_change_topic?(modes, membership, nickname) do
    if Modes.topic_locked?(modes) do
      case Membership.role(membership, nickname) do
        {:ok, :operator} -> :ok
        _ -> {:error, "You must be a channel operator to change the topic"}
      end
    else
      if Membership.member?(membership, nickname) do
        :ok
      else
        {:error, "You are not in this channel"}
      end
    end
  end

  @spec operator?(Membership.t(), String.t()) :: boolean()
  def operator?(membership, nickname) do
    case Membership.role(membership, nickname) do
      {:ok, :operator} -> true
      _ -> false
    end
  end
end
