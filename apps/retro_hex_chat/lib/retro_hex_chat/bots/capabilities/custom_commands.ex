defmodule RetroHexChat.Bots.Capabilities.CustomCommands do
  @moduledoc """
  Capability that handles custom !prefix commands defined by the bot owner.
  Commands are stored in `bot_custom_commands` and loaded into the GenServer state.
  """

  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Bots.Capability

  alias RetroHexChat.Bots.TemplateEngine

  @impl true
  @spec name() :: atom()
  def name, do: :custom_commands

  @impl true
  @spec description() :: String.t()
  def description, do: dgettext("bots", "Custom bot commands (!prefix trigger)")

  @impl true
  @spec handle_message(String.t(), String.t(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_message(content, author, ctx) do
    commands = Map.get(ctx.config, "commands", %{})
    prefix = ctx.command_prefix

    case parse_command(content, prefix, ctx.bot_name) do
      {:ok, trigger} ->
        lookup_command(trigger, commands, author, ctx)

      :not_a_command ->
        :ignore
    end
  end

  @impl true
  @spec handle_event(atom(), map(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_event(_event, _payload, _ctx), do: :ignore

  @impl true
  @spec default_config() :: map()
  def default_config, do: %{"enabled" => true}

  @impl true
  @spec validate_config(map()) :: :ok | {:error, String.t()}
  def validate_config(_), do: :ok

  # ── Helpers ──

  @spec parse_command(String.t(), String.t(), String.t()) :: {:ok, String.t()} | :not_a_command
  defp parse_command(content, prefix, bot_name) do
    trimmed = String.trim(content)

    # Try long format first: !BotName trigger
    full_prefix = prefix <> bot_name

    cond do
      String.starts_with?(trimmed, full_prefix) ->
        rest = String.trim_leading(trimmed, full_prefix) |> String.trim()
        extract_trigger(rest)

      String.starts_with?(trimmed, prefix) ->
        # Short format: !trigger (without bot name)
        rest = String.slice(trimmed, String.length(prefix)..-1//1) |> String.trim()
        extract_trigger(rest)

      true ->
        :not_a_command
    end
  end

  @spec extract_trigger(String.t()) :: {:ok, String.t()} | :not_a_command
  defp extract_trigger(rest) do
    trigger = rest |> String.split(" ", parts: 2) |> hd()

    if trigger != "" do
      {:ok, String.downcase(trigger)}
    else
      :not_a_command
    end
  end

  @spec lookup_command(String.t(), map(), String.t(), map()) ::
          RetroHexChat.Bots.Capability.capability_result()
  defp lookup_command(trigger, commands, author, ctx) do
    case Map.get(commands, trigger) do
      %{"response" => response, "enabled" => true} ->
        vars = %{
          "nickname" => author,
          "channel" => ctx.channel,
          "prefix" => ctx.command_prefix,
          "botname" => ctx.bot_name
        }

        {:reply, TemplateEngine.render(response, vars)}

      %{"response" => response} when is_binary(response) ->
        vars = %{
          "nickname" => author,
          "channel" => ctx.channel,
          "prefix" => ctx.command_prefix,
          "botname" => ctx.bot_name
        }

        {:reply, TemplateEngine.render(response, vars)}

      _ ->
        :ignore
    end
  end
end
