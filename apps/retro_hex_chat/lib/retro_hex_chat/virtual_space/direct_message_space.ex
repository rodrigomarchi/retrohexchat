defmodule RetroHexChat.VirtualSpace.DirectMessageSpace do
  @moduledoc """
  Stable identity helpers for direct-message virtual spaces.

  A DM space is keyed by the two participants' normalized nicknames, independent
  of who opened the conversation first. Display nicknames stay in the token and
  process state so the room can render the same casing the chat UI uses.
  """

  import Ecto.Query
  import RetroHexChat.Nickname, only: [matches: 2]

  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.Topics

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

  @doc """
  The two participants as they spell themselves.

  The id is folded to lowercase so the pair has one address whatever case was
  typed, which leaves the address unable to say how anybody writes their name.
  Whoever is online says it through presence; a registered nickname says it
  through its record; anyone else keeps the spelling they arrived with.
  """
  @spec as_shown([String.t()]) :: [String.t()]
  def as_shown(participants) when is_list(participants), do: Enum.map(participants, &shown/1)

  defp shown(nickname) do
    case Tracker.meta(Topics.presence(), nickname) do
      %{nickname: spelled} when is_binary(spelled) -> spelled
      _offline -> registered_spelling(nickname) || nickname
    end
  end

  defp registered_spelling(nickname) do
    RegisteredNick
    |> where([n], matches(n.nickname, nickname))
    |> select([n], n.nickname)
    |> limit(1)
    |> Repo.one()
  end
end
