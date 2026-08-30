defmodule RetroHexChat.Surfaces do
  @moduledoc """
  Which of a person's screens are still open, and what that decides.

  A person used to be exactly one process — the chat's LiveView — so its tab
  closing and the person leaving were the same event, and parting them from
  every channel was the right thing to do on the way out. A conference at
  `/call/:token` breaks that equivalence: the chat can close while the person is
  still in a room whose policy asks, on every rejoin and every moderation act,
  whether they are a member of the channel.

  So the channels are left when the **last** surface closes, and never before.
  The chat still does it itself when it is the last one — that path is
  unchanged and stays synchronous. When it is not, it hands the departure over
  here with `defer_part/3`, and this process runs it when the surface that
  outlived it goes down.

  Surfaces are **monitored**, not asked to report. `terminate/2` does not run on
  every path a LiveView leaves by, and a crash must count out exactly like a
  close.

  What this deliberately does not do: it does not decide anything about
  presence. Being online is the chat session's fact, tracked and released by
  `ChatLive`; a game tab has never made someone look online and must not start
  now.

  The one hole left, and it is the one that was already there: a chat that
  *crashes* never hands a departure over, so if it crashes while a call is open
  the membership outlives both. That is what a chat crash does today with no
  call at all, and closing it means owning the channel list here, continuously,
  for a case that ends in a restart anyway.
  """
  use GenServer

  require Logger

  alias RetroHexChat.Channels.Departure

  @type kind :: module() | atom()

  @doc false
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Register the calling process as one of `nickname`'s open surfaces.

  Idempotent per process: a surface that registers twice is still one surface.
  """
  @spec open(String.t(), kind(), GenServer.server()) :: :ok
  def open(nickname, kind, server \\ __MODULE__) when is_binary(nickname) do
    GenServer.call(server, {:open, key(nickname), self(), kind})
  end

  @doc "How many surfaces `nickname` has open right now."
  @spec count(String.t(), GenServer.server()) :: non_neg_integer()
  def count(nickname, server \\ __MODULE__) when is_binary(nickname) do
    GenServer.call(server, {:count, key(nickname)})
  end

  @doc """
  Hand the channel departure over: run it when `nickname`'s last surface goes.

  Called by a chat that is closing while something else of this person's is
  still open. The channel list is snapshotted here rather than derived later
  for the same reason the whowas cache snapshots it: by the time it runs, the
  process that knew it is gone.
  """
  @spec defer_part(String.t(), [String.t()], String.t() | nil, GenServer.server()) :: :ok
  def defer_part(nickname, channels, reason, server \\ __MODULE__)
      when is_binary(nickname) and is_list(channels) do
    deferred = %{nickname: nickname, channels: channels, reason: reason}
    GenServer.call(server, {:defer, key(nickname), deferred})
  end

  @doc """
  Drop a handed-over departure.

  A chat that comes back owns the lifetime of the membership again, so what the
  previous one left behind must not fire under it later.
  """
  @spec cancel_deferred(String.t(), GenServer.server()) :: :ok
  def cancel_deferred(nickname, server \\ __MODULE__) when is_binary(nickname) do
    GenServer.call(server, {:cancel, key(nickname)})
  end

  @impl true
  @spec init(:ok) :: {:ok, map()}
  def init(:ok), do: {:ok, %{by_ref: %{}, by_nick: %{}}}

  @impl true
  def handle_call({:open, key, pid, kind}, _from, state) do
    if Map.has_key?(surfaces(state, key), pid) do
      {:reply, :ok, state}
    else
      ref = Process.monitor(pid)
      entry = entry(state, key)

      {:reply, :ok,
       %{
         state
         | by_ref: Map.put(state.by_ref, ref, {key, pid}),
           by_nick: Map.put(state.by_nick, key, %{entry | pids: Map.put(entry.pids, pid, kind)})
       }}
    end
  end

  def handle_call({:count, key}, _from, state) do
    {:reply, map_size(surfaces(state, key)), state}
  end

  # "When the last surface goes" is now, when there is none.
  def handle_call({:defer, key, deferred}, _from, state) do
    case Map.get(state.by_nick, key) do
      nil ->
        run_deferred(deferred)
        {:reply, :ok, state}

      entry ->
        {:reply, :ok,
         %{state | by_nick: Map.put(state.by_nick, key, %{entry | deferred: deferred})}}
    end
  end

  def handle_call({:cancel, key}, _from, state) do
    case Map.get(state.by_nick, key) do
      nil ->
        {:reply, :ok, state}

      entry ->
        {:reply, :ok, %{state | by_nick: Map.put(state.by_nick, key, %{entry | deferred: nil})}}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    case Map.pop(state.by_ref, ref) do
      {{key, ^pid}, by_ref} ->
        {:noreply, %{state | by_ref: by_ref, by_nick: forget(state.by_nick, key, pid)}}

      {_other, _by_ref} ->
        {:noreply, state}
    end
  end

  def handle_info(message, state) do
    Logger.debug("RetroHexChat.Surfaces ignored #{inspect(message)}")
    {:noreply, state}
  end

  defp entry(state, key), do: Map.get(state.by_nick, key, %{pids: %{}, deferred: nil})

  defp surfaces(state, key), do: entry(state, key).pids

  # The last surface for this person just went. If a chat handed a departure
  # over before it left, this is the moment it was waiting for.
  defp forget(by_nick, key, pid) do
    case Map.get(by_nick, key) do
      nil ->
        by_nick

      entry ->
        entry = %{entry | pids: Map.delete(entry.pids, pid)}

        if entry.pids == %{} do
          run_deferred(entry.deferred)
          Map.delete(by_nick, key)
        else
          Map.put(by_nick, key, entry)
        end
    end
  end

  defp run_deferred(nil), do: :ok

  # Off this process: parting N channels is N calls into N channel servers, and
  # this one has to stay free to notice the next surface going down.
  defp run_deferred(%{nickname: nickname, channels: channels, reason: reason}) do
    Task.start(fn -> Departure.part_all(nickname, channels, reason) end)
    :ok
  end

  defp key(nickname), do: String.downcase(nickname)
end
