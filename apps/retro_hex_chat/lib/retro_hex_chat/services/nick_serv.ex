defmodule RetroHexChat.Services.NickServ do
  @moduledoc """
  NickServ: nick registration and protection service.

  Password hashing/verification (bcrypt) and all DB access run in the CALLER
  process (e.g. the connecting LiveView), NOT inside this GenServer. bcrypt is
  a deliberately expensive, CPU-bound dirty-NIF; running it inside a singleton
  GenServer's `handle_call` would serialize every register/identify/registered?
  behind one mailbox (head-of-line blocking), so a burst of logins would queue
  and each wait seconds. Instead, N concurrent logins hash in N caller processes
  in parallel (bounded only by dirty schedulers).

  This GenServer owns ONLY cheap in-memory runtime state: the set of currently
  `identified` nicknames and the per-nick identify-timeout `timers`. Concurrent
  registration of the same nick is guarded by the DB unique index on `nickname`,
  not by this process.
  """
  use Gettext, backend: RetroHexChat.Gettext
  use GenServer

  require Logger

  alias RetroHexChat.Observability
  alias RetroHexChat.Services.Queries
  alias RetroHexChat.Services.RegisteredNick

  @default_identify_timeout_ms 60_000

  # -- Public API (register/identify/registered?/info/ghost/drop/admin run in
  #    the CALLER process; only the identified-set + timer state touches the
  #    GenServer, via cheap calls/casts) --

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    timeout_ms = Keyword.get(opts, :identify_timeout_ms, @default_identify_timeout_ms)
    GenServer.start_link(__MODULE__, %{identify_timeout_ms: timeout_ms}, name: name)
  end

  @spec register(String.t(), String.t(), GenServer.server()) ::
          {:ok, String.t()} | {:error, String.t()}
  def register(nickname, password, server \\ __MODULE__) do
    Observability.span(
      [:retro_hex_chat, :accounts, :nickserv, :register],
      %{},
      fn -> do_register(nickname, password, server) end
    )
  end

  defp do_register(nickname, password, server) do
    if Queries.get_setting("registration") == "closed" do
      {:error,
       dgettext("services", "Registration is currently closed by the server administrator")}
    else
      # bcrypt hash happens in RegisteredNick.registration_changeset, in THIS
      # (caller) process. The DB unique index handles concurrent same-nick races.
      case Queries.insert_registered_nick(nickname, password) do
        {:ok, _} ->
          GenServer.call(server, {:add_identified, nickname})

          {:ok,
           dgettext("services", "Nickname %{nickname} registered successfully",
             nickname: nickname
           )}

        {:error, changeset} ->
          {:error, format_changeset_error(changeset)}
      end
    end
  end

  @spec identify(String.t(), String.t(), GenServer.server()) ::
          {:ok, String.t()} | {:error, String.t()}
  def identify(nickname, password, server \\ __MODULE__) do
    Observability.span(
      [:retro_hex_chat, :accounts, :nickserv, :identify],
      %{},
      fn -> do_identify(nickname, password, server) end
    )
  end

  defp do_identify(nickname, password, server) do
    case Queries.find_by_nickname(nickname) do
      nil ->
        # Equalize timing so an unregistered nick can't be told apart from a
        # wrong password (user-enumeration guard). Runs in the caller.
        Bcrypt.no_user_verify()

        {:error,
         dgettext("services", "Nickname %{nickname} is not registered", nickname: nickname)}

      %RegisteredNick{} = nick ->
        if RegisteredNick.verify_password(nick, password) do
          Queries.update_last_seen(nick)
          GenServer.call(server, {:mark_identified, nickname})

          {:ok, dgettext("services", "You are now identified as %{nickname}", nickname: nickname)}
        else
          {:error, dgettext("services", "Invalid password")}
        end
    end
  end

  @spec registered?(String.t(), GenServer.server()) :: boolean()
  def registered?(nickname, _server \\ __MODULE__) do
    Queries.find_by_nickname(nickname) != nil
  end

  @spec info(String.t(), GenServer.server()) :: {:ok, map()} | {:error, String.t()}
  def info(nickname, server \\ __MODULE__) do
    case Queries.find_by_nickname(nickname) do
      nil ->
        {:error,
         dgettext("services", "Nickname %{nickname} is not registered", nickname: nickname)}

      %RegisteredNick{} = nick ->
        {:ok,
         %{
           nickname: nick.nickname,
           registered_at: nick.registered_at,
           last_seen_at: nick.last_seen_at,
           identified: GenServer.call(server, {:identified?, nickname})
         }}
    end
  end

  @spec ghost(String.t(), String.t(), String.t(), GenServer.server()) ::
          {:ok, String.t()} | {:error, String.t()}
  def ghost(target_nick, password, requester_nick, _server \\ __MODULE__) do
    Observability.span(
      [:retro_hex_chat, :accounts, :nickserv, :ghost],
      %{},
      fn -> do_ghost(target_nick, password, requester_nick) end
    )
  end

  defp do_ghost(target_nick, password, requester_nick) do
    case Queries.find_by_nickname(target_nick) do
      nil ->
        {:error,
         dgettext("services", "Nickname %{target_nick} is not registered",
           target_nick: target_nick
         )}

      %RegisteredNick{} = nick ->
        if RegisteredNick.verify_password(nick, password) do
          broadcast_ghost_disconnect(target_nick, requester_nick)

          {:ok,
           dgettext("services", "Ghost command sent for %{target_nick}", target_nick: target_nick)}
        else
          {:error, dgettext("services", "Invalid password")}
        end
    end
  end

  @spec drop(String.t(), String.t(), GenServer.server()) ::
          {:ok, String.t()} | {:error, String.t()}
  def drop(nickname, password, server \\ __MODULE__) do
    Observability.span(
      [:retro_hex_chat, :accounts, :nickserv, :drop],
      %{},
      fn -> do_drop(nickname, password, server) end
    )
  end

  defp do_drop(nickname, password, server) do
    case Queries.find_by_nickname(nickname) do
      nil ->
        {:error,
         dgettext("services", "Nickname %{nickname} is not registered", nickname: nickname)}

      %RegisteredNick{} = nick ->
        if RegisteredNick.verify_password(nick, password) do
          Queries.delete_registered_nick(nick)
          GenServer.cast(server, {:remove_identified, nickname})
          {:ok, dgettext("services", "Registration for %{nickname} dropped", nickname: nickname)}
        else
          {:error, dgettext("services", "Invalid password")}
        end
    end
  end

  @spec admin_drop(String.t(), GenServer.server()) ::
          {:ok, String.t()} | {:error, String.t()}
  def admin_drop(nickname, server \\ __MODULE__) do
    Observability.span(
      [:retro_hex_chat, :accounts, :nickserv, :admin_drop],
      %{},
      fn -> do_admin_drop(nickname, server) end
    )
  end

  defp do_admin_drop(nickname, server) do
    case Queries.find_by_nickname(nickname) do
      nil ->
        {:error,
         dgettext("services", "Nickname %{nickname} is not registered", nickname: nickname)}

      %RegisteredNick{} = nick ->
        Queries.delete_registered_nick(nick)
        GenServer.cast(server, {:remove_identified, nickname})

        {:ok,
         dgettext("services", "Registration for %{nickname} dropped by admin", nickname: nickname)}
    end
  end

  @spec admin_reset_password(String.t(), String.t(), GenServer.server()) ::
          {:ok, String.t()} | {:error, String.t()}
  def admin_reset_password(nickname, new_password, _server \\ __MODULE__) do
    Observability.span(
      [:retro_hex_chat, :accounts, :nickserv, :admin_reset_password],
      %{},
      fn -> do_admin_reset_password(nickname, new_password) end
    )
  end

  defp do_admin_reset_password(nickname, new_password) do
    case Queries.find_by_nickname(nickname) do
      nil ->
        {:error,
         dgettext("services", "Nickname %{nickname} is not registered", nickname: nickname)}

      %RegisteredNick{} ->
        new_hash = Bcrypt.hash_pwd_salt(new_password)

        case Queries.update_password_hash(nickname, new_hash) do
          {:ok, _} ->
            {:ok,
             dgettext("services", "Password for %{nickname} has been reset", nickname: nickname)}

          {:error, _} ->
            {:error,
             dgettext("services", "Failed to reset password for %{nickname}", nickname: nickname)}
        end
    end
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

  @doc """
  Re-mark a nickname as identified without a password, for a reconnect that
  already proves prior identification (a signed `chat_pre_identified` session).
  Restores the in-memory set after a restart/deploy wiped it, keeping it in sync
  with the client's identity so downstream checks (virtual spaces, P2P) agree.
  Only takes effect for a registered nickname.
  """
  @spec restore_identified(String.t(), GenServer.server()) :: :ok
  def restore_identified(nickname, server \\ __MODULE__) do
    GenServer.cast(server, {:restore_identified, nickname})
  end

  # -- GenServer callbacks (cheap in-memory state only: identified set + timers,
  #    no bcrypt, no heavy DB in the hot path) --

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
  def handle_call({:add_identified, nickname}, _from, state) do
    # Registration auto-identifies (no timer to cancel, no broadcast — matches
    # historical behavior; register callers don't expect :nickserv_identified).
    {:reply, :ok, %{state | identified: MapSet.put(state.identified, nickname)}}
  end

  def handle_call({:mark_identified, nickname}, _from, state) do
    {:reply, :ok, mark_identified(state, nickname)}
  end

  def handle_call({:identified?, nickname}, _from, state) do
    {:reply, MapSet.member?(state.identified, nickname), state}
  end

  def handle_call(:list_identified, _from, state) do
    {:reply, MapSet.to_list(state.identified), state}
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

  def handle_cast({:restore_identified, nickname}, state) do
    if Queries.find_by_nickname(nickname) != nil do
      {:noreply, %{state | identified: MapSet.put(state.identified, nickname)}}
    else
      {:noreply, state}
    end
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
           {:force_rename, %{reason: dgettext("services", "Identify timeout (60s)")}}
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

  defp broadcast_ghost_disconnect(target_nick, requester_nick) do
    case Phoenix.PubSub.broadcast(
           RetroHexChat.PubSub,
           "user:#{target_nick}",
           {:force_disconnect,
            %{
              reason:
                dgettext("services", "Ghosted by %{requester_nick}",
                  requester_nick: requester_nick
                )
            }}
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
      dgettext("services", "%{field}: %{errors}", field: field, errors: Enum.join(errors, ", "))
    end)
  end
end
