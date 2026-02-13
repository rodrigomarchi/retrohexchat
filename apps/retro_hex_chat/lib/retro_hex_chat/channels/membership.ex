defmodule RetroHexChat.Channels.Membership do
  @moduledoc """
  In-memory membership tracking for a channel.
  Maps nicknames to their role and join time.
  """

  @type role :: :owner | :operator | :half_operator | :voiced | :regular
  @type member_info :: %{role: role(), joined_at: DateTime.t()}
  @type t :: %__MODULE__{members: %{String.t() => member_info()}}

  defstruct members: %{}

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec add(t(), String.t(), role()) :: t()
  def add(%__MODULE__{members: members} = m, nickname, role \\ :regular) do
    info = %{role: role, joined_at: DateTime.utc_now()}
    %{m | members: Map.put(members, nickname, info)}
  end

  @spec remove(t(), String.t()) :: t()
  def remove(%__MODULE__{members: members} = m, nickname) do
    %{m | members: Map.delete(members, nickname)}
  end

  @spec rename(t(), String.t(), String.t()) :: t()
  def rename(%__MODULE__{members: members} = m, old_nick, new_nick) do
    case Map.pop(members, old_nick) do
      {nil, _} -> m
      {info, rest} -> %{m | members: Map.put(rest, new_nick, info)}
    end
  end

  @spec member?(t(), String.t()) :: boolean()
  def member?(%__MODULE__{members: members}, nickname) do
    Map.has_key?(members, nickname)
  end

  @spec role(t(), String.t()) :: {:ok, role()} | {:error, :not_member}
  def role(%__MODULE__{members: members}, nickname) do
    case Map.fetch(members, nickname) do
      {:ok, %{role: role}} -> {:ok, role}
      :error -> {:error, :not_member}
    end
  end

  @spec set_role(t(), String.t(), role()) :: t()
  def set_role(%__MODULE__{members: members} = m, nickname, new_role) do
    case Map.fetch(members, nickname) do
      {:ok, info} -> %{m | members: Map.put(members, nickname, %{info | role: new_role})}
      :error -> m
    end
  end

  @spec rank(role()) :: non_neg_integer()
  def rank(:owner), do: 4
  def rank(:operator), do: 3
  def rank(:half_operator), do: 2
  def rank(:voiced), do: 1
  def rank(:regular), do: 0

  @spec owners(t()) :: [String.t()]
  def owners(%__MODULE__{members: members}) do
    members
    |> Enum.filter(fn {_, %{role: role}} -> role == :owner end)
    |> Enum.map(fn {nick, _} -> nick end)
    |> Enum.sort()
  end

  @spec operators(t()) :: [String.t()]
  def operators(%__MODULE__{members: members}) do
    members
    |> Enum.filter(fn {_, %{role: role}} -> role == :operator end)
    |> Enum.map(fn {nick, _} -> nick end)
    |> Enum.sort()
  end

  @spec half_operators(t()) :: [String.t()]
  def half_operators(%__MODULE__{members: members}) do
    members
    |> Enum.filter(fn {_, %{role: role}} -> role == :half_operator end)
    |> Enum.map(fn {nick, _} -> nick end)
    |> Enum.sort()
  end

  @spec voiced(t()) :: [String.t()]
  def voiced(%__MODULE__{members: members}) do
    members
    |> Enum.filter(fn {_, %{role: role}} -> role == :voiced end)
    |> Enum.map(fn {nick, _} -> nick end)
    |> Enum.sort()
  end

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
    |> Enum.map(fn {nick, %{role: role}} -> {nick, role} end)
    |> Enum.sort_by(fn {nick, _} -> nick end)
  end
end
