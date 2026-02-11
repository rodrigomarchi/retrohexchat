defmodule RetroHexChat.Services.NickServ do
  @moduledoc "NickServ: Nick registration and protection service."
  use GenServer

  require Logger

  alias RetroHexChat.Services.Queries
  alias RetroHexChat.Services.RegisteredNick

  @default_identify_timeout_ms 60_000

  # -- Public API --

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    timeout_ms = Keyword.get(opts, :identify_timeout_ms, @default_identify_timeout_ms)
    GenServer.start_link(__MODULE__, %{identify_timeout_ms: timeout_ms}, name: name)
  end

  @spec register(String.t(), String.t(), GenServer.server()) ::
          {:ok, String.t()} | {:error, String.t()}
  def register(nickname, password, server \\ __MODULE__) do
    GenServer.call(server, {:register, nickname, password})
  end

  @spec identify(String.t(), String.t(), GenServer.server()) ::
          {:ok, String.t()} | {:error, String.t()}
  def identify(nickname, password, server \\ __MODULE__) do
    GenServer.call(server, {:identify, nickname, password})
  end

  @spec registered?(String.t(), GenServer.server()) :: boolean()
  def registered?(nickname, server \\ __MODULE__) do
    GenServer.call(server, {:registered?, nickname})
  end

  @spec info(String.t(), GenServer.server()) :: {:ok, map()} | {:error, String.t()}
  def info(nickname, server \\ __MODULE__) do
    GenServer.call(server, {:info, nickname})
  end

  @spec ghost(String.t(), String.t(), GenServer.server()) ::
          {:ok, String.t()} | {:error, String.t()}
  def ghost(target_nick, requester_nick, server \\ __MODULE__) do
    GenServer.call(server, {:ghost, target_nick, requester_nick})
  end

  @spec drop(String.t(), String.t(), GenServer.server()) ::
          {:ok, String.t()} | {:error, String.t()}
  def drop(nickname, password, server \\ __MODULE__) do
    GenServer.call(server, {:drop, nickname, password})
  end

  @spec start_identify_timer(String.t(), GenServer.server()) :: :ok
  def start_identify_timer(nickname, server \\ __MODULE__) do
    GenServer.cast(server, {:start_identify_timer, nickname})
  end

  @spec cancel_identify_timer(String.t(), GenServer.server()) :: :ok
  def cancel_identify_timer(nickname, server \\ __MODULE__) do
    GenServer.cast(server, {:cancel_identify_timer, nickname})
  end

  # -- GenServer callbacks --

  @impl true
  def init(config) do
    timeout_ms = Map.get(config, :identify_timeout_ms, @default_identify_timeout_ms)

    {:ok,
     %{
       identify_timeout_ms: timeout_ms,
       identified: MapSet.new(),
       timers: %{}
     }}
  end

  @impl true
  def handle_call({:register, nickname, password}, _from, state) do
    case Queries.insert_registered_nick(nickname, password) do
      {:ok, _} ->
        new_state = %{state | identified: MapSet.put(state.identified, nickname)}
        {:reply, {:ok, "Nickname #{nickname} registered successfully"}, new_state}

      {:error, changeset} ->
        msg = format_changeset_error(changeset)
        {:reply, {:error, msg}, state}
    end
  end

  def handle_call({:identify, nickname, password}, _from, state) do
    case Queries.find_by_nickname(nickname) do
      nil ->
        {:reply, {:error, "Nickname #{nickname} is not registered"}, state}

      %RegisteredNick{} = nick ->
        if RegisteredNick.verify_password(nick, password) do
          Queries.update_last_seen(nick)
          new_state = mark_identified(state, nickname)
          {:reply, {:ok, "You are now identified as #{nickname}"}, new_state}
        else
          {:reply, {:error, "Invalid password"}, state}
        end
    end
  end

  def handle_call({:registered?, nickname}, _from, state) do
    {:reply, Queries.find_by_nickname(nickname) != nil, state}
  end

  def handle_call({:info, nickname}, _from, state) do
    case Queries.find_by_nickname(nickname) do
      nil ->
        {:reply, {:error, "Nickname #{nickname} is not registered"}, state}

      %RegisteredNick{} = nick ->
        info = %{
          nickname: nick.nickname,
          registered_at: nick.registered_at,
          last_seen_at: nick.last_seen_at,
          identified: MapSet.member?(state.identified, nickname)
        }

        {:reply, {:ok, info}, state}
    end
  end

  def handle_call({:ghost, target_nick, requester_nick}, _from, state) do
    cond do
      not MapSet.member?(state.identified, requester_nick) ->
        {:reply, {:error, "You must be identified to use GHOST"}, state}

      Queries.find_by_nickname(target_nick) == nil ->
        {:reply, {:error, "Nickname #{target_nick} is not registered"}, state}

      true ->
        case Phoenix.PubSub.broadcast(
               RetroHexChat.PubSub,
               "user:#{target_nick}",
               {:force_disconnect, %{reason: "Ghosted by #{requester_nick}"}}
             ) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.warning("PubSub broadcast to user:#{target_nick} failed: #{inspect(reason)}")
        end

        {:reply, {:ok, "Ghost command sent for #{target_nick}"}, state}
    end
  end

  def handle_call({:drop, nickname, password}, _from, state) do
    case Queries.find_by_nickname(nickname) do
      nil ->
        {:reply, {:error, "Nickname #{nickname} is not registered"}, state}

      %RegisteredNick{} = nick ->
        if RegisteredNick.verify_password(nick, password) do
          Queries.delete_registered_nick(nick)
          new_state = %{state | identified: MapSet.delete(state.identified, nickname)}
          {:reply, {:ok, "Registration for #{nickname} dropped"}, new_state}
        else
          {:reply, {:error, "Invalid password"}, state}
        end
    end
  end

  @impl true
  def handle_cast({:start_identify_timer, nickname}, state) do
    timer_ref =
      Process.send_after(self(), {:identify_timeout, nickname}, state.identify_timeout_ms)

    new_timers = Map.put(state.timers, nickname, timer_ref)
    {:noreply, %{state | timers: new_timers}}
  end

  def handle_cast({:cancel_identify_timer, nickname}, state) do
    case Map.pop(state.timers, nickname) do
      {nil, _} ->
        {:noreply, state}

      {ref, new_timers} ->
        Process.cancel_timer(ref)
        {:noreply, %{state | timers: new_timers}}
    end
  end

  @impl true
  def handle_info({:identify_timeout, nickname}, state) do
    new_timers = Map.delete(state.timers, nickname)

    case Phoenix.PubSub.broadcast(
           RetroHexChat.PubSub,
           "user:#{nickname}",
           {:force_rename, %{reason: "Identify timeout (60s)"}}
         ) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("PubSub broadcast to user:#{nickname} failed: #{inspect(reason)}")
    end

    {:noreply, %{state | timers: new_timers}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # -- Private helpers --

  defp mark_identified(state, nickname) do
    new_state =
      case Map.pop(state.timers, nickname) do
        {nil, _} ->
          %{state | identified: MapSet.put(state.identified, nickname)}

        {ref, new_timers} ->
          Process.cancel_timer(ref)

          %{
            state
            | identified: MapSet.put(state.identified, nickname),
              timers: new_timers
          }
      end

    broadcast_identified(nickname)
    new_state
  end

  defp broadcast_identified(nickname) do
    case Phoenix.PubSub.broadcast(
           RetroHexChat.PubSub,
           "user:#{nickname}",
           {:nickserv_identified, %{nickname: nickname}}
         ) do
      :ok -> :ok
      {:error, reason} -> Logger.warning("PubSub identify broadcast failed: #{inspect(reason)}")
    end
  end

  defp format_changeset_error(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join(", ", fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
  end
end
