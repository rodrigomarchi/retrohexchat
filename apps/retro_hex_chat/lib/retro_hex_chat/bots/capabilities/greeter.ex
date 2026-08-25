defmodule RetroHexChat.Bots.Capabilities.Greeter do
  @moduledoc """
  Capability that welcomes people into a channel, and optionally says goodbye.

  A welcome is up to three things arriving together, because they are addressed
  to different audiences:

  - `public_greeting` goes to the room, and only the first time this bot meets
    this name here. It is the one line of a welcome that persists.
  - `greeting` goes to the newcomer alone, and says what the room is for.
  - `onboarding_1` through `onboarding_4` go to the newcomer alone, and say what
    IRC is: how to join a room, how to speak privately, how to change a nick.
    They repeat verbatim across every room of a server so that whichever door
    somebody comes through teaches the same thing.

  Whether somebody is new is `RetroHexChat.Bots.GreetingLedger`'s answer, not a
  timer in this process: the announcement is public and a hundred and forty-four
  bots re-announcing the whole readership after a deploy is not a small mistake.
  Farewells keep the in-memory window — they are disabled in every seeded script,
  and a duplicate goodbye costs nobody anything.

  The line ceiling is four and it is a flood budget, not a style rule. Nothing
  paces a welcome: `RetroHexChat.Bots.Pace` runs in the Oban worker that
  publishes feeds, and the join path does not go through it. A private notice
  never reaches the reader's flood counter, but an operator who points
  `onboarding_delivery` at the channel is spending real budget, four lines of it.
  """

  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Bots.Capability

  alias RetroHexChat.Bots.GreetingLedger
  alias RetroHexChat.Bots.TemplateEngine

  @default_repeat_window_sec 3600
  @delivery_modes ~w(public channel_notice private_notice silent)
  @max_onboarding_lines 4
  @onboarding_keys Enum.map(1..@max_onboarding_lines, &"onboarding_#{&1}")

  @impl true
  @spec name() :: atom()
  def name, do: :greeter

  @impl true
  @spec description() :: String.t()
  def description, do: dgettext("bots", "Greet users on join, say goodbye on part")

  @doc "Every config key that holds one line of the onboarding tour, in order."
  @spec onboarding_keys() :: [String.t()]
  def onboarding_keys, do: @onboarding_keys

  @doc "How many lines of onboarding a bot may carry."
  @spec max_onboarding_lines() :: pos_integer()
  def max_onboarding_lines, do: @max_onboarding_lines

  @impl true
  @spec handle_message(String.t(), String.t(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_message(_content, _author, _ctx), do: :ignore

  @impl true
  @spec handle_event(atom(), map(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_event(:user_joined, %{nickname: nickname}, ctx) do
    welcome(nickname, ctx)
  end

  def handle_event(:user_left, %{nickname: nickname}, ctx) do
    farewell = Map.get(ctx.config, "farewell")
    delivery = Map.get(ctx.config, "farewell_delivery", legacy_delivery())

    render_if_present(:farewell, farewell, nickname, delivery, ctx)
  end

  def handle_event(_event, _payload, _ctx), do: :ignore

  @impl true
  @spec default_config() :: map()
  def default_config do
    %{
      "greeting" => default_greeting(),
      "public_greeting" => nil,
      "farewell" => nil,
      "greeting_delivery" => "private_notice",
      "onboarding_delivery" => "private_notice",
      "farewell_delivery" => "silent",
      "repeat_window_sec" => @default_repeat_window_sec,
      "enabled" => true
    }
  end

  @impl true
  @spec validate_config(map()) :: :ok | {:error, String.t()}
  def validate_config(config) do
    cond do
      invalid_delivery?(Map.get(config, "greeting_delivery")) ->
        {:error, delivery_error("greeting_delivery")}

      invalid_delivery?(Map.get(config, "onboarding_delivery")) ->
        {:error, delivery_error("onboarding_delivery")}

      invalid_delivery?(Map.get(config, "farewell_delivery")) ->
        {:error, delivery_error("farewell_delivery")}

      invalid_repeat_window?(Map.get(config, "repeat_window_sec")) ->
        {:error, dgettext("bots", "Repeat window must be a non-negative number of seconds")}

      true ->
        :ok
    end
  end

  @impl true
  @spec init_state(map()) :: map()
  def init_state(_config), do: %{recent_deliveries: %{}}

  # ── Welcome ───────────────────────────────────────────────

  @spec welcome(String.t(), map()) :: RetroHexChat.Bots.Capability.capability_result()
  defp welcome(nickname, ctx) do
    vars = template_vars(nickname, ctx)
    announcement = render_line(Map.get(ctx.config, "public_greeting"), vars)

    private =
      [Map.get(ctx.config, "greeting", default_greeting()) | onboarding_templates(ctx.config)]
      |> Enum.map(&render_line(&1, vars))
      |> Enum.reject(&is_nil/1)

    # Asked before the ledger is touched, so a bot that stands in every room
    # without greeting — the moderator every script provisions — never writes a
    # row for a join it was never going to answer.
    if announcement == nil and private == [] do
      :ignore
    else
      compose(nickname, ctx, announcement, private)
    end
  end

  @spec compose(String.t(), map(), String.t() | nil, [String.t()]) ::
          RetroHexChat.Bots.Capability.capability_result()
  defp compose(nickname, ctx, announcement, private) do
    window_sec = repeat_window_sec(ctx.config)

    case GreetingLedger.impl().record(ctx.bot_id, ctx.channel, nickname, window_sec) do
      :within_window ->
        :ignore

      met_before_or_not ->
        greeting_delivery = Map.get(ctx.config, "greeting_delivery", legacy_delivery())
        onboarding_delivery = Map.get(ctx.config, "onboarding_delivery", greeting_delivery)

        announcement
        |> announcement_outputs(met_before_or_not, nickname)
        |> Kernel.++(private_outputs(private, greeting_delivery, onboarding_delivery, nickname))
        |> emit()
    end
  end

  # The room hears about somebody once. `:window_elapsed` is a reader coming back
  # after long enough to want the orientation again, not a new arrival, and
  # announcing them a second time is how a busy room fills with bot chatter.
  @spec announcement_outputs(String.t() | nil, atom(), String.t()) :: [map()]
  defp announcement_outputs(nil, _kind, _nickname), do: []
  defp announcement_outputs(_content, :window_elapsed, _nickname), do: []

  defp announcement_outputs(content, :first_time, nickname),
    do: [output(content, "public", nickname)]

  @spec private_outputs([String.t()], String.t(), String.t(), String.t()) :: [map()]
  defp private_outputs([], _greeting_delivery, _onboarding_delivery, _nickname), do: []

  defp private_outputs([greeting | onboarding], greeting_delivery, onboarding_delivery, nickname) do
    [output(greeting, greeting_delivery, nickname)] ++
      Enum.map(onboarding, &output(&1, onboarding_delivery, nickname))
  end

  # A bot carrying only a greeting produces exactly what it produced before this
  # capability learned to say more than one thing.
  @spec emit([map()]) :: RetroHexChat.Bots.Capability.capability_result()
  defp emit([]), do: :ignore
  defp emit([output]), do: {:bot_output, output}
  defp emit(outputs), do: {:multi_output, outputs}

  @spec output(String.t(), String.t() | atom(), String.t()) :: map()
  defp output(content, delivery, nickname) do
    %{content: content, delivery: normalize_delivery(delivery), target: nickname}
  end

  @spec onboarding_templates(map()) :: [String.t()]
  defp onboarding_templates(config), do: Enum.map(@onboarding_keys, &Map.get(config, &1))

  @spec render_line(String.t() | nil, map()) :: String.t() | nil
  defp render_line(nil, _vars), do: nil
  defp render_line("", _vars), do: nil

  defp render_line(template, vars) when is_binary(template),
    do: TemplateEngine.render(template, vars)

  defp render_line(_template, _vars), do: nil

  @spec template_vars(String.t(), map()) :: map()
  defp template_vars(nickname, ctx) do
    %{
      "nickname" => nickname,
      "channel" => ctx.channel,
      "prefix" => ctx.command_prefix,
      "botname" => ctx.bot_name
    }
  end

  @spec default_greeting() :: String.t()
  defp default_greeting, do: dgettext("bots", "Welcome, {nickname}!")

  # ── Farewell ──────────────────────────────────────────────

  @spec render_if_present(atom(), String.t() | nil, String.t(), String.t(), map()) ::
          RetroHexChat.Bots.Capability.capability_result()
  defp render_if_present(_event, nil, _nickname, _delivery, _ctx), do: :ignore
  defp render_if_present(_event, "", _nickname, _delivery, _ctx), do: :ignore

  defp render_if_present(event, template, nickname, delivery, ctx) do
    content = TemplateEngine.render(template, template_vars(nickname, ctx))
    window_sec = repeat_window_sec(ctx.config)

    case record_delivery(ctx.capability_state, event, nickname, ctx.channel, content, window_sec) do
      :repeat ->
        :ignore

      {:ok, new_state} ->
        {:bot_output, output(content, delivery, nickname), new_state}
    end
  end

  # ── Shared ────────────────────────────────────────────────

  # Stored greeter configs that predate delivery settings keep their behavior:
  # a message in the channel. New bots created from default_config/0 are quieter.
  @spec legacy_delivery() :: String.t()
  defp legacy_delivery, do: "public"

  @spec delivery_error(String.t()) :: String.t()
  defp delivery_error(field) do
    dgettext(
      "bots",
      "%{field} must be public, channel_notice, private_notice, or silent",
      field: field
    )
  end

  @spec normalize_delivery(String.t() | atom() | nil) :: String.t()
  defp normalize_delivery(delivery) when is_atom(delivery) and not is_nil(delivery),
    do: delivery |> Atom.to_string() |> normalize_delivery()

  defp normalize_delivery(delivery) when delivery in @delivery_modes, do: delivery
  defp normalize_delivery(_delivery), do: legacy_delivery()

  @spec repeat_window_sec(map()) :: non_neg_integer()
  defp repeat_window_sec(config) do
    case Map.get(config, "repeat_window_sec", 0) do
      value when is_integer(value) and value >= 0 -> value
      value when is_binary(value) -> parse_repeat_window(value)
      _ -> 0
    end
  end

  defp parse_repeat_window(value) do
    case Integer.parse(value) do
      {n, ""} when n >= 0 -> n
      _ -> 0
    end
  end

  @spec record_delivery(
          map() | nil,
          atom(),
          String.t(),
          String.t(),
          String.t(),
          non_neg_integer()
        ) ::
          :repeat | {:ok, map()}
  defp record_delivery(capability_state, event, nickname, channel, content, window_sec) do
    recent = Map.get(capability_state || %{}, :recent_deliveries, %{})

    if window_sec <= 0 do
      {:ok, Map.put(capability_state || %{}, :recent_deliveries, recent)}
    else
      now = System.monotonic_time(:millisecond)
      cutoff = now - window_sec * 1000
      key = delivery_key(event, channel, nickname, content)
      pruned = prune_recent(recent, cutoff)

      case Map.get(pruned, key) do
        seen_at when is_integer(seen_at) and seen_at >= cutoff ->
          :repeat

        _ ->
          {:ok, Map.put(capability_state || %{}, :recent_deliveries, Map.put(pruned, key, now))}
      end
    end
  end

  defp delivery_key(event, channel, nickname, content) do
    {event, String.downcase(channel), String.downcase(nickname), content}
  end

  defp prune_recent(recent, cutoff) do
    recent
    |> Enum.reject(fn {_key, timestamp} -> timestamp < cutoff end)
    |> Map.new()
  end

  defp invalid_delivery?(nil), do: false
  defp invalid_delivery?(delivery), do: normalize_delivery(delivery) != delivery

  defp invalid_repeat_window?(nil), do: false
  defp invalid_repeat_window?(value) when is_integer(value), do: value < 0
  defp invalid_repeat_window?(_value), do: true
end
