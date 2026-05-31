defmodule RetroHexChat.Services.NickServ do
  @moduledoc "NickServ: Nick registration and protection service."
  use Gettext, backend: RetroHexChat.Gettext
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

  @spec ghost(String.t(), String.t(), String.t(), GenServer.server()) ::
          {:ok, String.t()} | {:error, String.t()}
  def ghost(target_nick, password, requester_nick, server \\ __MODULE__) do
    GenServer.call(server, {:ghost, target_nick, password, requester_nick})
  end

  @spec drop(String.t(), String.t(), GenServer.server()) ::
          {:ok, String.t()} | {:error, String.t()}
  def drop(nickname, password, server \\ __MODULE__) do
    GenServer.call(server, {:drop, nickname, password})
  end

  @spec admin_drop(String.t(), GenServer.server()) ::
          {:ok, String.t()} | {:error, String.t()}
  def admin_drop(nickname, server \\ __MODULE__) do
    GenServer.call(server, {:admin_drop, nickname})
  end

  @spec admin_reset_password(String.t(), String.t(), GenServer.server()) ::
          {:ok, String.t()} | {:error, String.t()}
  def admin_reset_password(nickname, new_password, server \\ __MODULE__) do
    GenServer.call(server, {:admin_reset_password, nickname, new_password})
  end

  @spec identified?(String.t(), GenServer.server()) :: boolean()
  def identified?(nickname, server \\ __MODULE__) do
    GenServer.call(server, {:identified?, nickname})
  end

  @spec start_identify_timer(String.t(), GenServer.server()) :: :ok
  def start_identify_timer(nickname, server \\ __MODULE__) do
    GenServer.cast(server, {:start_identify_timer, nickname})
  end

  @spec cancel_identify_timer(String.t(), GenServer.server()) :: :ok
  def cancel_identify_timer(nickname, server \\ __MODULE__) do
    GenServer.cast(server, {:cancel_identify_timer, nickname})
  end

  @spec list_identified(GenServer.server()) :: [String.t()]
  def list_identified(server \\ __MODULE__) do
    GenServer.call(server, :list_identified)
  end

  @spec remove_identified(String.t(), GenServer.server()) :: :ok
  def remove_identified(nickname, server \\ __MODULE__) do
    GenServer.cast(server, {:remove_identified, nickname})
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
    if Queries.get_setting("registration") == "closed" do
      {:reply, {:error, gettext("Registration is currently closed by the server administrator")},
       state}
    else
      case Queries.insert_registered_nick(nickname, password) do
        {:ok, _} ->
          new_state = %{state | identified: MapSet.put(state.identified, nickname)}

          {:reply,
           {:ok, gettext("Nickname %{nickname} registered successfully", nickname: nickname)},
           new_state}

        {:error, changeset} ->
          msg = format_changeset_error(changeset)
          {:reply, {:error, msg}, state}
      end
    end
  end

  def handle_call({:identify, nickname, password}, _from, state) do
    case Queries.find_by_nickname(nickname) do
      nil ->
        {:reply, {:error, gettext("Nickname %{nickname} is not registered", nickname: nickname)},
         state}

      %RegisteredNick{} = nick ->
        if RegisteredNick.verify_password(nick, password) do
          Queries.update_last_seen(nick)
          new_state = mark_identified(state, nickname)

          {:reply, {:ok, gettext("You are now identified as %{nickname}", nickname: nickname)},
           new_state}
        else
          {:reply, {:error, gettext("Invalid password")}, state}
        end
    end
  end

  def handle_call({:registered?, nickname}, _from, state) do
    {:reply, Queries.find_by_nickname(nickname) != nil, state}
  end

  def handle_call({:identified?, nickname}, _from, state) do
    {:reply, MapSet.member?(state.identified, nickname), state}
  end

  def handle_call({:info, nickname}, _from, state) do
    case Queries.find_by_nickname(nickname) do
      nil ->
        {:reply, {:error, gettext("Nickname %{nickname} is not registered", nickname: nickname)},
         state}

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

  def handle_call({:ghost, target_nick, password, requester_nick}, _from, state) do
    case Queries.find_by_nickname(target_nick) do
      nil ->
        {:reply,
         {:error, gettext("Nickname %{target_nick} is not registered", target_nick: target_nick)},
         state}

      %RegisteredNick{} = nick ->
        handle_ghost_for_registered_nick(nick, target_nick, password, requester_nick, state)
    end
  end

  def handle_call(:list_identified, _from, state) do
    {:reply, MapSet.to_list(state.identified), state}
  end

  def handle_call({:drop, nickname, password}, _from, state) do
    case Queries.find_by_nickname(nickname) do
      nil ->
        {:reply, {:error, gettext("Nickname %{nickname} is not registered", nickname: nickname)},
         state}

      %RegisteredNick{} = nick ->
        if RegisteredNick.verify_password(nick, password) do
          Queries.delete_registered_nick(nick)
          new_state = %{state | identified: MapSet.delete(state.identified, nickname)}

          {:reply, {:ok, gettext("Registration for %{nickname} dropped", nickname: nickname)},
           new_state}
        else
          {:reply, {:error, gettext("Invalid password")}, state}
        end
    end
  end

  def handle_call({:admin_drop, nickname}, _from, state) do
    case Queries.find_by_nickname(nickname) do
      nil ->
        {:reply, {:error, gettext("Nickname %{nickname} is not registered", nickname: nickname)},
         state}

      %RegisteredNick{} = nick ->
        Queries.delete_registered_nick(nick)
        new_state = %{state | identified: MapSet.delete(state.identified, nickname)}

        {:reply,
         {:ok, gettext("Registration for %{nickname} dropped by admin", nickname: nickname)},
         new_state}
    end
  end

  def handle_call({:admin_reset_password, nickname, new_password}, _from, state) do
    case Queries.find_by_nickname(nickname) do
      nil ->
        {:reply, {:error, gettext("Nickname %{nickname} is not registered", nickname: nickname)},
         state}

      %RegisteredNick{} ->
        new_hash = Bcrypt.hash_pwd_salt(new_password)

        case Queries.update_password_hash(nickname, new_hash) do
          {:ok, _} ->
            {:reply,
             {:ok, gettext("Password for %{nickname} has been reset", nickname: nickname)}, state}

          {:error, _} ->
            {:reply,
             {:error, gettext("Failed to reset password for %{nickname}", nickname: nickname)},
             state}
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

  def handle_cast({:remove_identified, nickname}, state) do
    {:noreply, %{state | identified: MapSet.delete(state.identified, nickname)}}
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
           {:force_rename, %{reason: gettext("Identify timeout (60s)")}}
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

  defp handle_ghost_for_registered_nick(nick, target_nick, password, requester_nick, state) do
    if RegisteredNick.verify_password(nick, password) do
      broadcast_ghost_disconnect(target_nick, requester_nick)

      {:reply, {:ok, gettext("Ghost command sent for %{target_nick}", target_nick: target_nick)},
       state}
    else
      {:reply, {:error, gettext("Invalid password")}, state}
    end
  end

  defp broadcast_ghost_disconnect(target_nick, requester_nick) do
    case Phoenix.PubSub.broadcast(
           RetroHexChat.PubSub,
           "user:#{target_nick}",
           {:force_disconnect,
            %{reason: gettext("Ghosted by %{requester_nick}", requester_nick: requester_nick)}}
         ) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("PubSub broadcast to user:#{target_nick} failed: #{inspect(reason)}")
    end
  end

  defp format_changeset_error(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join(", ", fn {field, errors} ->
      gettext("%{field}: %{errors}", field: field, errors: Enum.join(errors, ", "))
    end)
  end
end
