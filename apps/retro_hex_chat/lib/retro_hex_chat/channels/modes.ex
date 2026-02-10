defmodule RetroHexChat.Channels.Modes do
  @moduledoc """
  Channel mode parsing and enforcement.
  Supported flags: m (moderated), i (invite-only), t (topic lock), k (key), l (limit).
  User modes (o, v) are handled by Membership, not here.
  """

  @type t :: %__MODULE__{
          flags: MapSet.t(),
          key: String.t() | nil,
          limit: non_neg_integer() | nil
        }

  defstruct flags: MapSet.new(), key: nil, limit: nil

  # MapSet is opaque but struct construction exposes internals to Dialyzer.
  @dialyzer {:nowarn_function, new: 0}

  @channel_flags %{
    "m" => :moderated,
    "i" => :invite_only,
    "t" => :topic_lock
  }

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec moderated?(t()) :: boolean()
  def moderated?(%__MODULE__{flags: flags}), do: MapSet.member?(flags, :moderated)

  @spec invite_only?(t()) :: boolean()
  def invite_only?(%__MODULE__{flags: flags}), do: MapSet.member?(flags, :invite_only)

  @spec topic_locked?(t()) :: boolean()
  def topic_locked?(%__MODULE__{flags: flags}), do: MapSet.member?(flags, :topic_lock)

  @spec has_key?(t()) :: boolean()
  def has_key?(%__MODULE__{key: nil}), do: false
  def has_key?(%__MODULE__{}), do: true

  @spec has_limit?(t()) :: boolean()
  def has_limit?(%__MODULE__{limit: nil}), do: false
  def has_limit?(%__MODULE__{}), do: true

  @spec apply_changes(t(), String.t(), [String.t()]) :: {:ok, t()} | {:error, String.t()}
  def apply_changes(%__MODULE__{} = modes, mode_string, params \\ []) do
    case parse_mode_string(mode_string, params) do
      {:ok, changes} -> {:ok, apply_parsed(modes, changes)}
      {:error, _} = err -> err
    end
  end

  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{flags: flags, key: key, limit: limit}) do
    flag_chars =
      flags
      |> MapSet.to_list()
      |> Enum.map(fn
        :moderated -> "m"
        :invite_only -> "i"
        :topic_lock -> "t"
      end)
      |> Enum.sort()

    extra =
      [if(key, do: "k"), if(limit, do: "l")]
      |> Enum.reject(&is_nil/1)

    chars = flag_chars ++ extra

    case chars do
      [] -> ""
      _ -> "+" <> Enum.join(chars)
    end
  end

  defp parse_mode_string(mode_string, params) do
    case String.split(mode_string, "", trim: true) do
      ["+" | flags] -> {:ok, parse_flags(:add, flags, params)}
      ["-" | flags] -> {:ok, parse_flags(:remove, flags, params)}
      _ -> {:error, "Invalid mode string: must start with + or -"}
    end
  end

  defp parse_flags(action, flags, params) do
    {changes, _remaining_params} =
      Enum.reduce(flags, {[], params}, fn flag, {acc, remaining} ->
        parse_single_flag(action, flag, acc, remaining)
      end)

    Enum.reverse(changes)
  end

  defp parse_single_flag(:add, "k", acc, [param | rest]), do: {[{:add, :key, param} | acc], rest}
  defp parse_single_flag(:add, "k", acc, []), do: {[{:add, :key, nil} | acc], []}
  defp parse_single_flag(:remove, "k", acc, params), do: {[{:remove, :key, nil} | acc], params}

  defp parse_single_flag(:add, "l", acc, [param | rest]),
    do: {[{:add, :limit, param} | acc], rest}

  defp parse_single_flag(:add, "l", acc, []), do: {[{:add, :limit, nil} | acc], []}
  defp parse_single_flag(:remove, "l", acc, params), do: {[{:remove, :limit, nil} | acc], params}

  defp parse_single_flag(action, flag, acc, params) do
    case Map.fetch(@channel_flags, flag) do
      {:ok, flag_atom} -> {[{action, :flag, flag_atom} | acc], params}
      :error -> {acc, params}
    end
  end

  defp apply_parsed(modes, changes) do
    Enum.reduce(changes, modes, fn
      {:add, :flag, flag}, m ->
        %{m | flags: MapSet.put(m.flags, flag)}

      {:remove, :flag, flag}, m ->
        %{m | flags: MapSet.delete(m.flags, flag)}

      {:add, :key, key}, m ->
        %{m | key: key}

      {:remove, :key, _}, m ->
        %{m | key: nil}

      {:add, :limit, limit}, m when is_binary(limit) ->
        case Integer.parse(limit) do
          {n, ""} when n > 0 -> %{m | limit: n}
          _ -> m
        end

      {:remove, :limit, _}, m ->
        %{m | limit: nil}

      _, m ->
        m
    end)
  end
end
