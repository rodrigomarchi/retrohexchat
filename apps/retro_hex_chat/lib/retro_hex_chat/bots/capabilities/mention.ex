defmodule RetroHexChat.Bots.Capabilities.Mention do
  @moduledoc """
  Capability that responds when the bot is mentioned by name in a message.
  """
  @behaviour RetroHexChat.Bots.Capability

  alias RetroHexChat.Bots.TemplateEngine

  @impl true
  @spec name() :: atom()
  def name, do: :mention

  @impl true
  @spec description() :: String.t()
  def description, do: "Respond when mentioned by name"

  @impl true
  @spec handle_message(String.t(), String.t(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_message(content, author, ctx) do
    if mentions_bot?(content, ctx.bot_nickname) do
      response = Map.get(ctx.config, "response", default_response())

      vars = %{
        "nickname" => author,
        "channel" => ctx.channel,
        "prefix" => ctx.command_prefix,
        "botname" => ctx.bot_name
      }

      {:reply, TemplateEngine.render(response, vars)}
    else
      :ignore
    end
  end

  @impl true
  @spec handle_event(atom(), map(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_event(_event, _payload, _ctx), do: :ignore

  @impl true
  @spec default_config() :: map()
  def default_config do
    %{"response" => default_response(), "enabled" => true}
  end

  @impl true
  @spec validate_config(map()) :: :ok | {:error, String.t()}
  def validate_config(%{"response" => r}) when is_binary(r) and byte_size(r) > 0, do: :ok
  def validate_config(%{"response" => _}), do: {:error, "Response must be a non-empty string"}
  def validate_config(_), do: :ok

  @spec default_response() :: String.t()
  defp default_response, do: "Hi {nickname}! Try {prefix}help for my commands."

  @spec mentions_bot?(String.t(), String.t()) :: boolean()
  defp mentions_bot?(content, bot_nickname) do
    downcased = String.downcase(content)
    String.contains?(downcased, String.downcase(bot_nickname))
  end
end
