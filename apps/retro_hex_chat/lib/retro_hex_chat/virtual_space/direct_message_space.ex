defmodule RetroHexChat.VirtualSpace.DirectMessageSpace do
  @moduledoc """
  Stable identity helpers for direct-message virtual spaces.

  A DM space is keyed by the two participants' normalized nicknames, independent
  of who opened the conversation first. Display nicknames stay in the token and
  process state so the room can render the same casing the chat UI uses.
  """

  @prefix "dm:"

  @spec space_id(String.t(), String.t()) :: String.t()
  def space_id(nick_a, nick_b) do
    [nick_a, nick_b]
    |> Enum.map(&normalize_nickname/1)
    |> Enum.sort()
    |> Enum.join(":")
    |> then(&(@prefix <> &1))
  end

  @spec normalize_participants([String.t()]) ::
          {:ok, [String.t()]} | {:error, :invalid_participants}
  def normalize_participants(participants) when is_list(participants) do
    participants =
      participants
      |> Enum.map(&to_string/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq_by(&normalize_nickname/1)

    if length(participants) == 2 do
      {:ok, participants}
    else
      {:error, :invalid_participants}
    end
  end

  def normalize_participants(_participants), do: {:error, :invalid_participants}

  @spec member?([String.t()], String.t()) :: boolean()
  def member?(participants, nickname) when is_list(participants) do
    target = normalize_nickname(nickname)
    Enum.any?(participants, &(normalize_nickname(&1) == target))
  end

  def member?(_participants, _nickname), do: false

  @spec normalize_nickname(String.t()) :: String.t()
  def normalize_nickname(nickname) do
    nickname
    |> to_string()
    |> String.downcase()
  end
end
