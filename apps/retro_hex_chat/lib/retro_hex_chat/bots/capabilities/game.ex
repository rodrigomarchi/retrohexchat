defmodule RetroHexChat.Bots.Capabilities.Game do
  use Gettext, backend: RetroHexChat.Gettext

  @moduledoc """
  Makes a bot the voice of the games in its rooms.

  A finished match is said by `Games.Announcer`, and an arcade game somebody
  started by `Arcade.Announcer`; each asks which bot in a room carries this
  capability and speaks under its name — the weekly challenge and the daily
  digests too. A room with no such bot hears nothing about its games:
  `/bot set <bot> game_announce off`, or `/bot part`.

  In a game's room, and in the feed, the bot also talks about the game itself,
  from `Games.RoomFacts`:

  - whoever arrives is told privately what the game is and where its week
    stands, after the greeter's welcome and at most once an hour. The hour is
    kept in this process, so a restart forgets it: after a deploy somebody
    already in the room is told again the next time they arrive;
  - `!ranking`, `!challenge`, `!recent` and `!howto` are answered in the room;
  - a room nothing has been said in yet gets one line saying what it is for,
    when the bot comes into it, so nobody opens it to a blank page.

  An arcade game's room gets what the game is and its controls, on arrival, as its
  opening line and to `!howto`; it keeps no score, so nothing else.
  """
  @behaviour RetroHexChat.Bots.Capability

  alias RetroHexChat.Bots.Server
  alias RetroHexChat.Chat.Queries, as: ChatQueries
  alias RetroHexChat.Games.RoomFacts
  alias RetroHexChat.Nickname

  @welcome_window_ms :timer.hours(1)

  @impl true
  @spec name() :: atom()
  def name, do: :game

  @impl true
  @spec description() :: String.t()
  def description,
    do:
      dgettext(
        "bots",
        "Announces Retro Games matches and arcade games as they start, rankings and the weekly challenge"
      )

  @impl true
  @spec handle_message(String.t(), String.t(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_message(content, _author, ctx) do
    with {:ok, command} <- parse_command(content, ctx),
         {:ok, text} <- RoomFacts.answer(command, ctx.channel) do
      {:reply, signed(text, ctx)}
    else
      _not_a_question -> :ignore
    end
  end

  @impl true
  @spec handle_event(atom(), map(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_event(event, %{nickname: nickname}, ctx)
      when event in [:user_joined, :visitor_arrived] and is_binary(nickname) do
    welcomed = Map.get(ctx.capability_state, :welcomed, %{})
    key = {ctx.channel, Nickname.key(nickname)}
    now = System.monotonic_time(:millisecond)

    with false <- recently?(welcomed, key, now),
         [_ | _] = lines <- RoomFacts.welcome(ctx.channel) do
      outputs = Enum.map(lines, &private(signed(&1, ctx), nickname))
      {:multi_output, outputs, %{welcomed: welcomed |> prune(now) |> Map.put(key, now)}}
    else
      _already_told_or_not_a_game_room -> :ignore
    end
  end

  def handle_event(_event, _payload, _ctx), do: :ignore

  @doc """
  Schedule the look at every room the bot stands in that `intro/1` would
  speak in. Called by `Bots.Server` when the bot starts.
  """
  @impl true
  @spec init_timers(map(), atom(), map(), map()) :: map()
  def init_timers(server_state, cap_name, config, cap_state) do
    server_state.channels
    |> Map.keys()
    |> Enum.reduce(server_state, &init_channel_timers(&2, cap_name, config, cap_state, &1))
  end

  @doc "The same look, for a room the bot came into after it started."
  @impl true
  @spec init_channel_timers(map(), atom(), map(), map(), String.t()) :: map()
  def init_channel_timers(server_state, cap_name, _config, _cap_state, channel) do
    if server_state.enabled and channel_enabled?(server_state, channel) and
         RoomFacts.room?(channel),
       do: Server.schedule_capability_timer(server_state, cap_name, %{channel: channel}, 0),
       else: server_state
  end

  @impl true
  @spec handle_timer(term(), map(), RetroHexChat.Bots.Capability.bot_context()) ::
          {RetroHexChat.Bots.Capability.capability_result(), map()}
  def handle_timer(%{channel: channel}, cap_state, ctx) do
    with true <- silent?(channel),
         intro when is_binary(intro) <- RoomFacts.intro(channel) do
      {{:reply, signed(intro, ctx)}, cap_state}
    else
      _said_something_already -> {:ignore, cap_state}
    end
  end

  def handle_timer(_payload, cap_state, _ctx), do: {:ignore, cap_state}

  @impl true
  @spec init_state(map()) :: map()
  def init_state(_config), do: %{welcomed: %{}}

  @impl true
  @spec default_config() :: map()
  def default_config, do: %{"enabled" => true}

  @impl true
  @spec validate_config(map()) :: :ok | {:error, String.t()}
  def validate_config(_config), do: :ok

  @impl true
  @spec commands() :: [%{trigger: String.t(), description: String.t()}]
  def commands do
    [
      %{trigger: "ranking", description: dgettext("bots", "The game's ranking")},
      %{
        trigger: "challenge",
        description: dgettext("bots", "This week's challenge and who leads it")
      },
      %{trigger: "recent", description: dgettext("bots", "The latest public matches")},
      %{trigger: "howto", description: dgettext("bots", "Controls and how to start")}
    ]
  end

  # `!ranking`, or `!Scoreboard ranking`, in any case.
  defp parse_command(content, ctx) do
    prefix = String.downcase(ctx.command_prefix)
    words = content |> String.trim() |> String.downcase() |> String.split()
    bot = prefix <> Nickname.key(ctx.bot_nickname)

    case words do
      [^bot, command] -> {:ok, command}
      [prefix_and_command] -> strip_prefix(prefix_and_command, prefix)
      _other -> :error
    end
  end

  defp strip_prefix(word, prefix) do
    case String.split_at(word, String.length(prefix)) do
      {^prefix, command} when command != "" -> {:ok, command}
      _other -> :error
    end
  end

  defp channel_enabled?(server_state, channel),
    do: get_in(server_state, [:channels, channel, :enabled]) != false

  defp silent?(channel), do: ChatQueries.list_messages(channel, limit: 1).items == []

  defp recently?(welcomed, key, now) do
    case Map.get(welcomed, key) do
      nil -> false
      at -> now - at < @welcome_window_ms
    end
  end

  defp prune(welcomed, now),
    do: Map.reject(welcomed, fn {_key, at} -> now - at >= @welcome_window_ms end)

  defp private(content, nickname),
    do: %{content: content, delivery: :private_notice, target: nickname}

  # The same signature the provisioning scripts give every bot line.
  defp signed(text, ctx), do: "\x0309\x02[#{ctx.bot_nickname}]\x0F #{text}"
end
