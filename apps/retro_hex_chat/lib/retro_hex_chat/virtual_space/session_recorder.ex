defmodule RetroHexChat.VirtualSpace.SessionRecorder do
  @moduledoc """
  Writes down what happened in a space, from outside the space.

  A gathering starts when somebody walks into an empty world and ends when the
  last of them leaves, and both of those are facts about a process. This one
  **monitors** that process rather than being part of it, for the reason
  `Surfaces` gives for doing the same: `terminate/2` does not run on every path
  a process leaves by, and a world that crashes has to count out exactly like
  one that emptied. A session left open because nobody wrote its ending is a
  card that says a party is still going a week later.

  Who was there is told to it by the join, one nickname at a time, and it is
  **not** read off the roster. A channel space draws every member of the channel
  on its map whether or not they ever opened it, so the roster answers "who
  belongs here" and the ended card asks "who actually came". There is no
  departure recorded for the same reason there is no way to observe one: a
  channel viewer leaving is a `viewer_count` going down with no nickname
  attached to it, and a `left_at` written from anything else would be invented.
  Neither of the two numbers the card shows — how long, how many — needs one.

  Nothing in here is allowed to take the process down. It holds the monitors for
  every space in the system, so a write that fails for one gathering must not
  lose the record of all the others: the failure is logged, that gathering goes
  unrecorded, and `RuntimeStaleCleanup` closes whatever is left behind.

  **A failed write exits as often as it raises.** The message that matters most
  here is a `:DOWN`, and a world going down while the database pool is going
  down with it — a node shutting down, a test's connection owner exiting — makes
  the closing `UPDATE` exit rather than raise. A `rescue` alone would let that
  through and take the whole recorder with it, which is how one dying space
  becomes every space losing its monitor.
  """
  use GenServer

  require Logger

  alias RetroHexChat.VirtualSpace.Queries
  alias RetroHexChat.VirtualSpace.Registry, as: SpaceRegistry
  alias RetroHexChat.VirtualSpace.Schema.Session

  @typedoc "What the caller that opened a space needs in order to write its card."
  @type opened :: %{token: String.t(), id: integer()}

  @doc false
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Opens a gathering for a space whose world has just started.

  Synchronous because the caller is about to write a card from what comes back.
  Returns `nil` when the record could not be written, and the caller carries on:
  a space you can enter without a card beats a card you cannot enter a space
  without.
  """
  @spec opened(String.t(), :channel | :direct_message, pid(), map(), GenServer.server()) ::
          opened() | nil
  def opened(space_id, kind, pid, actor, server \\ __MODULE__) do
    GenServer.call(server, {:opened, space_id, kind, pid, actor})
  catch
    :exit, reason ->
      Logger.warning("Space session recorder unavailable: #{inspect(reason)}")
      nil
  end

  @doc """
  Notes that somebody walked into a space that already had a gathering going.

  Asynchronous: the person is already through the door, and a record of them
  being there is not worth a round trip on the way in.
  """
  @spec arrived(String.t(), String.t(), GenServer.server()) :: :ok
  def arrived(space_id, nickname, server \\ __MODULE__) do
    GenServer.cast(server, {:arrived, space_id, nickname})
  catch
    :exit, _reason -> :ok
  end

  @doc "The gathering currently open in a space, or `nil`."
  @spec open_session(String.t()) :: Session.t() | nil
  def open_session(space_id) when is_binary(space_id),
    do: Queries.open_session_for_space(space_id)

  @doc "One gathering by its token, open or over."
  @spec get_session(String.t()) :: Session.t() | nil
  def get_session(token) when is_binary(token), do: Queries.get_session_by_token(token)

  @doc "How many distinct people walked into one gathering."
  @spec count_visitors(integer()) :: non_neg_integer()
  def count_visitors(session_id), do: Queries.count_visitors(session_id)

  @impl true
  @spec init(:ok) :: {:ok, map(), {:continue, :reconcile}}
  def init(:ok) do
    {:ok, %{monitors: %{}, spaces: %{}}, {:continue, :reconcile}}
  end

  # A restart of this process is a restart of every monitor it held. The worlds
  # that survived it are picked back up; the ones that did not are closed here
  # rather than left for the daily sweep to find.
  @impl true
  @spec handle_continue(:reconcile, map()) :: {:noreply, map()}
  def handle_continue(:reconcile, state) do
    {:noreply,
     guard(state, fn -> Enum.reduce(Queries.list_open_sessions(), state, &readopt/2) end)}
  end

  @impl true
  @spec handle_call({:opened, String.t(), atom(), pid(), map()}, GenServer.from(), map()) ::
          {:reply, opened() | nil, map()}
  def handle_call({:opened, space_id, kind, pid, actor}, _from, state) do
    case open(state, space_id, kind, pid, actor) do
      {:ok, session, state} -> {:reply, %{token: session.token, id: session.id}, state}
      {:error, state} -> {:reply, nil, state}
    end
  end

  @impl true
  @spec handle_cast({:arrived, String.t(), String.t()}, map()) :: {:noreply, map()}
  def handle_cast({:arrived, space_id, nickname}, state) do
    {:noreply, guard(state, fn -> record(state, space_id, nickname) end)}
  end

  @impl true
  @spec handle_info(term(), map()) :: {:noreply, map()}
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    {:noreply, guard(state, fn -> close(state, ref, down_reason(reason)) end)}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp open(state, space_id, kind, pid, actor) do
    attrs = %{
      token: generate_token(),
      space_id: space_id,
      kind: Atom.to_string(kind),
      status: "open",
      opened_by: Map.get(actor, :user_id),
      opened_by_nick: Map.get(actor, :nickname) || "?",
      opened_at: DateTime.utc_now()
    }

    case Queries.insert_session(attrs) do
      {:ok, session} ->
        Queries.record_arrival(session.id, attrs.opened_by_nick)
        {:ok, session, watch(state, session, pid)}

      {:error, changeset} ->
        Logger.warning("Space session insert failed: #{inspect(changeset.errors)}")
        {:error, state}
    end
  rescue
    error ->
      Logger.warning("Space session insert raised: #{inspect(error)}")
      {:error, state}
  catch
    :exit, reason ->
      Logger.warning("Space session insert exited: #{inspect(reason)}")
      {:error, state}
  end

  defp watch(state, %Session{} = session, pid) do
    ref = Process.monitor(pid)

    %{
      state
      | monitors: Map.put(state.monitors, ref, session),
        spaces: Map.put(state.spaces, session.space_id, ref)
    }
  end

  defp readopt(%Session{} = session, state) do
    case SpaceRegistry.lookup(registry_key(session)) do
      {:ok, pid} -> watch(state, session, pid)
      {:error, :not_found} -> close_session(state, session, "runtime_gone")
    end
  end

  defp registry_key(%Session{kind: "direct_message", space_id: space_id}),
    do: {:direct_message_space, space_id}

  defp registry_key(%Session{space_id: space_id}), do: {:channel_space, space_id}

  defp record(state, space_id, nickname) do
    with ref when is_reference(ref) <- Map.get(state.spaces, space_id),
         %Session{id: id} <- Map.get(state.monitors, ref) do
      Queries.record_arrival(id, nickname)
    end

    state
  end

  defp close(state, ref, reason) do
    case Map.pop(state.monitors, ref) do
      {nil, _monitors} ->
        state

      {%Session{} = session, monitors} ->
        state = %{state | monitors: monitors, spaces: Map.delete(state.spaces, session.space_id)}
        close_session(state, session, reason)
    end
  end

  defp close_session(state, %Session{} = session, reason) do
    case Queries.close_session(session, reason) do
      {:ok, _closed} ->
        state

      {:error, changeset} ->
        Logger.warning("Space session close failed: #{inspect(changeset.errors)}")
        state
    end
  end

  # The last stop before every DB touch in here. One gathering's row is never
  # worth the monitors of all the others, so a failure is written to the log and
  # the state is left exactly as it was — whether the database raised at it or
  # took its connection away underneath it.
  defp guard(state, work) do
    work.()
  rescue
    error ->
      Logger.warning("Space session recorder skipped a write: #{inspect(error)}")
      state
  catch
    :exit, reason ->
      Logger.warning("Space session recorder lost its connection: #{inspect(reason)}")
      state
  end

  defp down_reason(:normal), do: "emptied"
  defp down_reason(:shutdown), do: "shutdown"
  defp down_reason({:shutdown, _term}), do: "shutdown"
  defp down_reason(_reason), do: "crashed"

  defp generate_token do
    24
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end
