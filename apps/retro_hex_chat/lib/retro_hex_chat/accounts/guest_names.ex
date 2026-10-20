defmodule RetroHexChat.Accounts.GuestNames do
  @moduledoc """
  The guest name each visitor goes by, one per browser and never two alike.

  A visitor is a browser, not a tab: every tab a browser has open on the chat
  claims under the same browser id and gets the same name, so a person reading
  in five tabs is one guest, listed once. The name is held while any of those
  tabs is open — they are **monitored**, so a closed or crashed tab counts out
  the same way — and freed when the last one goes.

  The name is drawn, among those nobody holds, when the browser's first tab
  opens. It is not derived from the browser: once every tab has closed, the
  next visit draws again, so nothing ties one visit's name to the next. A
  browser with no id — one that refuses the cookie — has nothing to share a
  name with, so each of its tabs is a visitor of its own.

  Held only in this process, on this node: the names are a fact about who is
  watching right now, and nothing about a visitor outlives their tabs.
  """

  use GenServer

  alias RetroHexChat.Nickname

  # Four digits first, then five; past this many draws at each length the
  # names are crowded enough to stop drawing and count instead.
  @draws 64

  @doc """
  Starts the registry. `:uniform` is the draw, `:rand.uniform/1` unless a test
  needs to force two browsers onto the same name.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    uniform = Keyword.get(opts, :uniform, &:rand.uniform/1)
    GenServer.start_link(__MODULE__, uniform, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  The guest name for the calling process, a tab of the browser `browser_id`
  names. Every tab of one browser gets the same name; no two browsers share
  one. Idempotent per process.
  """
  @spec claim(String.t() | nil, GenServer.server()) :: String.t()
  def claim(browser_id, server \\ __MODULE__) do
    GenServer.call(server, {:claim, holder(browser_id, self()), self()})
  end

  @doc """
  Records the language the calling tab reads the chat in, against the guest
  name it claimed — the flag drawn beside that name in the user list. One per
  guest, the latest tab's: a visitor reading in two languages at once is rare,
  and the one they opened last is the one they chose last. A tab that claimed
  nothing has no name to record it against.
  """
  @spec put_locale(String.t(), GenServer.server()) :: :ok
  def put_locale(locale, server \\ __MODULE__) when is_binary(locale) do
    GenServer.call(server, {:put_locale, self(), locale})
  end

  @doc """
  The language each of these guests reads in, keyed by the name as asked.
  A name nobody holds, or whose holder never said, is absent.
  """
  @spec locales([String.t()], GenServer.server()) :: %{String.t() => String.t()}
  def locales(names, server \\ __MODULE__)
  def locales([], _server), do: %{}
  def locales(names, server), do: GenServer.call(server, {:locales, names})

  defp holder(browser_id, _pid) when is_binary(browser_id) and browser_id != "",
    do: {:browser, browser_id}

  defp holder(_browser_id, pid), do: {:tab, pid}

  # ── Server ────────────────────────────────────────────────────

  @impl true
  def init(uniform) do
    # holders: holder => %{name, tabs: %{pid => ref}, locale}; names: key(name) => holder;
    # tabs: pid => holder.
    {:ok, %{holders: %{}, names: %{}, tabs: %{}, uniform: uniform}}
  end

  @impl true
  def handle_call({:claim, holder, pid}, _from, state) do
    case state.holders do
      %{^holder => %{name: name, tabs: tabs}} when is_map_key(tabs, pid) ->
        {:reply, name, state}

      %{^holder => %{name: name}} ->
        {:reply, name, add_tab(state, holder, pid)}

      _none ->
        name = free_name(state)

        state =
          state
          |> put_in([:holders, holder], %{name: name, tabs: %{}})
          |> put_in([:names, Nickname.key(name)], holder)
          |> add_tab(holder, pid)

        {:reply, name, state}
    end
  end

  def handle_call({:put_locale, pid, locale}, _from, state) do
    case state.tabs do
      %{^pid => holder} -> {:reply, :ok, put_in(state, [:holders, holder, :locale], locale)}
      _unclaimed -> {:reply, :ok, state}
    end
  end

  def handle_call({:locales, names}, _from, state) do
    found =
      for name <- names,
          is_binary(name),
          holder = Map.get(state.names, Nickname.key(name)),
          locale = get_in(state.holders, [holder, :locale]),
          into: %{},
          do: {name, locale}

    {:reply, found, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    case Map.pop(state.tabs, pid) do
      {nil, _tabs} ->
        {:noreply, state}

      {holder, tabs} ->
        %{name: name, tabs: held} = Map.fetch!(state.holders, holder)
        held = Map.delete(held, pid)
        state = %{state | tabs: tabs}

        if map_size(held) == 0 do
          {:noreply,
           %{
             state
             | holders: Map.delete(state.holders, holder),
               names: Map.delete(state.names, Nickname.key(name))
           }}
        else
          {:noreply, put_in(state, [:holders, holder, :tabs], held)}
        end
    end
  end

  defp add_tab(state, holder, pid) do
    ref = Process.monitor(pid)

    state
    |> put_in([:holders, holder, :tabs, pid], ref)
    |> put_in([:tabs, pid], holder)
  end

  defp free_name(state) do
    draw(state, 1000, @draws) || draw(state, 10_000, @draws) || counted(state)
  end

  # `Guest` and a number of as many digits as `low` has.
  defp draw(_state, _low, 0), do: nil

  defp draw(state, low, left) do
    name = "Guest#{low + state.uniform.(low * 9) - 1}"
    if taken?(state, name), do: draw(state, low, left - 1), else: name
  end

  # Never held before on this node, so free without asking.
  defp counted(state) do
    name = "Guest#{100_000 + System.unique_integer([:positive, :monotonic])}"
    if taken?(state, name), do: counted(state), else: name
  end

  defp taken?(state, name), do: Map.has_key?(state.names, Nickname.key(name))
end
