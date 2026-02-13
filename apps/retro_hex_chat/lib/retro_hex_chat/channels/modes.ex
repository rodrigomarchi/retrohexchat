defmodule RetroHexChat.Channels.Modes do
  @moduledoc """
  Channel mode parsing and enforcement.
  Supported flags: m (moderated), i (invite-only), t (topic lock), k (key), l (limit),
  n (no external), s (secret), p (private), c (strip colors), R (registered only),
  K (no knock), j (join throttle).
  User modes (o, v, q, h) are handled by Membership, not here.
  """

  @type t :: %__MODULE__{
          flags: MapSet.t(),
          key: String.t() | nil,
          limit: non_neg_integer() | nil,
          join_throttle: {pos_integer(), pos_integer()} | nil
        }

  defstruct flags: MapSet.new(), key: nil, limit: nil, join_throttle: nil

  # MapSet is opaque but struct construction exposes internals to Dialyzer.
  @dialyzer {:nowarn_function, new: 0}

  @channel_flags %{
    "m" => :moderated,
    "i" => :invite_only,
    "t" => :topic_lock,
    "n" => :no_external,
    "s" => :secret,
    "p" => :private,
    "c" => :strip_colors,
    "R" => :registered_only,
    "K" => :no_knock
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

  @spec no_external?(t()) :: boolean()
  def no_external?(%__MODULE__{flags: flags}), do: MapSet.member?(flags, :no_external)

  @spec secret?(t()) :: boolean()
  def secret?(%__MODULE__{flags: flags}), do: MapSet.member?(flags, :secret)

  @spec private?(t()) :: boolean()
  def private?(%__MODULE__{flags: flags}), do: MapSet.member?(flags, :private)

  @spec strip_colors?(t()) :: boolean()
  def strip_colors?(%__MODULE__{flags: flags}), do: MapSet.member?(flags, :strip_colors)

  @spec registered_only?(t()) :: boolean()
  def registered_only?(%__MODULE__{flags: flags}), do: MapSet.member?(flags, :registered_only)

  @spec no_knock?(t()) :: boolean()
  def no_knock?(%__MODULE__{flags: flags}), do: MapSet.member?(flags, :no_knock)

  @spec has_join_throttle?(t()) :: boolean()
  def has_join_throttle?(%__MODULE__{join_throttle: nil}), do: false
  def has_join_throttle?(%__MODULE__{}), do: true

  @spec apply_changes(t(), String.t(), [String.t()]) :: {:ok, t()} | {:error, String.t()}
  def apply_changes(%__MODULE__{} = modes, mode_string, params \\ []) do
    case parse_mode_string(mode_string, params) do
      {:ok, changes} ->
        new_modes = apply_parsed(modes, changes)
        validate_mutual_exclusivity(new_modes)

      {:error, _} = err ->
        err
    end
  end

  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{flags: flags, key: key, limit: limit, join_throttle: join_throttle}) do
    flag_chars =
      flags
      |> MapSet.to_list()
      |> Enum.map(fn
        :moderated -> "m"
        :invite_only -> "i"
        :topic_lock -> "t"
        :no_external -> "n"
        :secret -> "s"
        :private -> "p"
        :strip_colors -> "c"
        :registered_only -> "R"
        :no_knock -> "K"
      end)
      |> Enum.sort()

    extra =
      [if(key, do: "k"), if(limit, do: "l"), if(join_throttle, do: "j")]
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

  defp parse_single_flag(:add, "j", acc, [param | rest]),
    do: {[{:add, :join_throttle, param} | acc], rest}

  defp parse_single_flag(:add, "j", acc, []), do: {[{:add, :join_throttle, nil} | acc], []}

  defp parse_single_flag(:remove, "j", acc, params),
    do: {[{:remove, :join_throttle, nil} | acc], params}

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

      {:add, :join_throttle, param}, m when is_binary(param) ->
        case parse_join_throttle(param) do
          {:ok, throttle} -> %{m | join_throttle: throttle}
          :error -> m
        end

      {:remove, :join_throttle, _}, m ->
        %{m | join_throttle: nil}

      _, m ->
        m
    end)
  end

  defp parse_join_throttle(param) do
    case String.split(param, ":") do
      [count_str, seconds_str] ->
        with {count, ""} <- Integer.parse(count_str),
             {seconds, ""} <- Integer.parse(seconds_str),
             true <- count > 0 and seconds > 0 do
          {:ok, {count, seconds}}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp validate_mutual_exclusivity(%__MODULE__{flags: flags} = modes) do
    if MapSet.member?(flags, :secret) and MapSet.member?(flags, :private) do
      {:error, "+s and +p are mutually exclusive"}
    else
      {:ok, modes}
    end
  end
end
