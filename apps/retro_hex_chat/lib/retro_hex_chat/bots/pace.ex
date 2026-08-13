defmodule RetroHexChat.Bots.Pace do
  @moduledoc """
  How fast a bot is allowed to speak.

  Flood protection lives in each reader's session: a nickname that exceeds
  `flood_threshold` messages in `flood_window_seconds` is auto-ignored by that
  reader for five minutes. Nothing on the server stops it, and nothing tells the
  bot it happened — the room simply goes quiet for whoever was counting. A wire
  bot publishing a feed page in one burst trips it every time.

  The limit is per **nickname**, not per channel or per feed, so this is too:
  a bot with five feeds on the same interval polls them together, and five
  polite feeds still add up to one impolite bot. Reservations are keyed by
  nickname for that reason.

  The pace is derived from the flood settings rather than written down, at half
  the rate that would trigger them. If the defaults move, this moves with them.
  """
  use GenServer

  alias RetroHexChat.Chat.FloodProtection

  require Logger

  @prune_interval_ms :timer.minutes(10)

  @doc """
  Reserves the next slot for `nickname` and returns how long to wait for it.

  The caller sleeps, then sends — never this process, which stays free to answer
  every other bot. A nickname that has been quiet longer than the interval gets
  a slot immediately; credit does not accumulate beyond that, so a bot idle for
  an hour still cannot open with a burst.
  """
  @spec reserve(String.t()) :: non_neg_integer()
  def reserve(nickname) when is_binary(nickname) do
    GenServer.call(__MODULE__, {:reserve, String.downcase(nickname)})
  catch
    :exit, _reason -> 0
  end

  @doc """
  Milliseconds between two messages from one bot.

  Half the rate that trips flood protection: the default 10 messages per 15
  seconds allows one every 1.5s, so a bot gets one every 3s. The margin is
  deliberate — a reader may lower the threshold on their own session, and the
  tracker counts a bot's channels together.
  """
  @spec interval_ms() :: pos_integer()
  def interval_ms do
    settings = FloodProtection.new()
    window_ms = FloodProtection.get_flood_window_seconds(settings) * 1000
    threshold = FloodProtection.get_flood_threshold(settings)

    ceil(window_ms / threshold * 2)
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl GenServer
  @spec init(keyword()) :: {:ok, map()}
  def init(_opts) do
    schedule_prune()
    {:ok, %{slots: %{}, interval_ms: interval_ms()}}
  end

  @impl GenServer
  def handle_call({:reserve, key}, _from, state) do
    now = System.monotonic_time(:millisecond)
    earliest = max(Map.get(state.slots, key, now), now)

    {:reply, earliest - now, put_in(state.slots[key], earliest + state.interval_ms)}
  end

  @impl GenServer
  def handle_info(:prune, state) do
    now = System.monotonic_time(:millisecond)
    # A slot in the past constrains nothing, so forgetting it changes no
    # behaviour — it only keeps the map the size of the talkative bots.
    slots = Map.filter(state.slots, fn {_key, at} -> at > now end)

    schedule_prune()
    {:noreply, %{state | slots: slots}}
  end

  def handle_info(_message, state), do: {:noreply, state}

  @spec schedule_prune() :: reference()
  defp schedule_prune, do: Process.send_after(self(), :prune, @prune_interval_ms)
end
