defmodule RetroHexChat.Channels.Membership do
  @moduledoc """
  In-memory membership tracking for a channel.
  Maps nicknames to their role and join time.

  Members are keyed by `Nickname.key/1`: `/op alice` finds the member who joined
  as `AlIcE`, and no two case variants of one nickname can both be inside. Each
  entry keeps the spelling the member chose, and that is the only spelling any
  function here hands out.
  """

  alias RetroHexChat.Nickname

  @type role :: :owner | :operator | :half_operator | :voiced | :regular | :bot
  @type member_info :: %{nick: String.t(), role: role(), joined_at: DateTime.t()}
  @type t :: %__MODULE__{members: %{Nickname.key() => member_info()}}

  defstruct members: %{}

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec add(t(), String.t(), role()) :: t()
  def add(%__MODULE__{members: members} = m, nickname, role \\ :regular) do
    info = %{nick: nickname, role: role, joined_at: DateTime.utc_now()}
    %{m | members: Map.put(members, Nickname.key(nickname), info)}
  end

  @spec remove(t(), String.t()) :: t()
  def remove(%__MODULE__{members: members} = m, nickname) do
    %{m | members: Map.delete(members, Nickname.key(nickname))}
  end

  @spec rename(t(), String.t(), String.t()) :: t()
  def rename(%__MODULE__{members: members} = m, old_nick, new_nick) do
    case Map.pop(members, Nickname.key(old_nick)) do
      {nil, _} ->
        m

      {info, rest} ->
        %{m | members: Map.put(rest, Nickname.key(new_nick), %{info | nick: new_nick})}
    end
  end

  @spec member?(t(), String.t()) :: boolean()
  def member?(%__MODULE__{members: members}, nickname) do
    Map.has_key?(members, Nickname.key(nickname))
  end

  @doc "How the member named by `nickname`, in any case, spells it."
  @spec display(t(), String.t()) :: {:ok, String.t()} | {:error, :not_member}
  def display(%__MODULE__{members: members}, nickname) do
    case Map.fetch(members, Nickname.key(nickname)) do
      {:ok, %{nick: nick}} -> {:ok, nick}
      :error -> {:error, :not_member}
    end
  end

  @spec role(t(), String.t()) :: {:ok, role()} | {:error, :not_member}
  def role(%__MODULE__{members: members}, nickname) do
    case Map.fetch(members, Nickname.key(nickname)) do
      {:ok, %{role: role}} -> {:ok, role}
      :error -> {:error, :not_member}
    end
  end

  @spec set_role(t(), String.t(), role()) :: t()
  def set_role(%__MODULE__{members: members} = m, nickname, new_role) do
    key = Nickname.key(nickname)

    case Map.fetch(members, key) do
      {:ok, info} -> %{m | members: Map.put(members, key, %{info | role: new_role})}
      :error -> m
    end
  end

  @spec rank(role()) :: non_neg_integer()
  def rank(:owner), do: 4
  def rank(:operator), do: 3
  def rank(:half_operator), do: 2
  def rank(:voiced), do: 1
  def rank(:regular), do: 0
  def rank(:bot), do: 0

  @spec owners(t()) :: [String.t()]
  def owners(%__MODULE__{} = m), do: with_role(m, :owner)

  @spec operators(t()) :: [String.t()]
  def operators(%__MODULE__{} = m), do: with_role(m, :operator)

  @spec half_operators(t()) :: [String.t()]
  def half_operators(%__MODULE__{} = m), do: with_role(m, :half_operator)

  @spec voiced(t()) :: [String.t()]
  def voiced(%__MODULE__{} = m), do: with_role(m, :voiced)

  @spec outranks?(t(), String.t(), String.t()) :: boolean()
  def outranks?(%__MODULE__{} = m, actor, target) do
    with {:ok, actor_role} <- role(m, actor),
         {:ok, target_role} <- role(m, target) do
      rank(actor_role) > rank(target_role)
    else
      _ -> false
    end
  end

  @spec count(t()) :: non_neg_integer()
  def count(%__MODULE__{members: members}), do: map_size(members)

  @spec to_list(t()) :: [{String.t(), role()}]
  def to_list(%__MODULE__{members: members}) do
    members
    |> Enum.map(fn {_key, %{nick: nick, role: role}} -> {nick, role} end)
    |> Enum.sort_by(fn {nick, _} -> nick end)
  end

  defp with_role(%__MODULE__{members: members}, wanted) do
    members
    |> Enum.filter(fn {_key, %{role: role}} -> role == wanted end)
    |> Enum.map(fn {_key, %{nick: nick}} -> nick end)
    |> Enum.sort()
  end
end
