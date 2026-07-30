defmodule RetroHexChat.Bots.Capabilities.Greeter do
  @moduledoc """
  Capability that greets users on join and optionally says goodbye on part.
  """

  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Bots.Capability

  alias RetroHexChat.Bots.TemplateEngine

  @default_repeat_window_sec 3600
  @delivery_modes ~w(public channel_notice private_notice silent)

  @impl true
  @spec name() :: atom()
  def name, do: :greeter

  @impl true
  @spec description() :: String.t()
  def description, do: dgettext("bots", "Greet users on join, say goodbye on part")

  @impl true
  @spec handle_message(String.t(), String.t(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_message(_content, _author, _ctx), do: :ignore

  @impl true
  @spec handle_event(atom(), map(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_event(:user_joined, %{nickname: nickname}, ctx) do
    greeting = Map.get(ctx.config, "greeting", default_greeting())
    delivery = Map.get(ctx.config, "greeting_delivery", legacy_delivery())

    render_if_present(:greeting, greeting, nickname, delivery, ctx)
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
      "farewell" => nil,
      "greeting_delivery" => "private_notice",
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
        {:error,
         dgettext(
           "bots",
           "Greeting delivery must be public, channel_notice, private_notice, or silent"
         )}

      invalid_delivery?(Map.get(config, "farewell_delivery")) ->
        {:error,
         dgettext(
           "bots",
           "Farewell delivery must be public, channel_notice, private_notice, or silent"
         )}

      invalid_repeat_window?(Map.get(config, "repeat_window_sec")) ->
        {:error, dgettext("bots", "Repeat window must be a non-negative number of seconds")}

      true ->
        :ok
    end
  end

  @impl true
  @spec init_state(map()) :: map()
  def init_state(_config), do: %{recent_deliveries: %{}}

  @spec default_greeting() :: String.t()
  defp default_greeting, do: dgettext("bots", "Welcome, {nickname}!")

  @spec render_if_present(atom(), String.t() | nil, String.t(), String.t(), map()) ::
          RetroHexChat.Bots.Capability.capability_result()
  defp render_if_present(_event, nil, _nickname, _delivery, _ctx), do: :ignore
  defp render_if_present(_event, "", _nickname, _delivery, _ctx), do: :ignore

  defp render_if_present(event, template, nickname, delivery, ctx) do
    vars = %{
      "nickname" => nickname,
      "channel" => ctx.channel,
      "prefix" => ctx.command_prefix,
      "botname" => ctx.bot_name
    }

    content = TemplateEngine.render(template, vars)
    window_sec = repeat_window_sec(ctx.config)

    case record_delivery(ctx.capability_state, event, nickname, ctx.channel, content, window_sec) do
      :repeat ->
        :ignore

      {:ok, new_state} ->
        {:bot_output,
         %{
           content: content,
           delivery: normalize_delivery(delivery),
           target: nickname
         }, new_state}
    end
  end

  # Stored greeter configs that predate delivery settings keep their behavior:
  # a message in the channel. New bots created from default_config/0 are quieter.
  @spec legacy_delivery() :: String.t()
  defp legacy_delivery, do: "public"

  @spec normalize_delivery(String.t() | atom() | nil) :: String.t()
  defp normalize_delivery(delivery) when is_atom(delivery),
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
