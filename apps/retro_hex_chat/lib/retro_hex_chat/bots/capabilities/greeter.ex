defmodule RetroHexChat.Bots.Capabilities.Greeter do
  @moduledoc """
  Capability that greets users on join and optionally says goodbye on part.
  """
  @behaviour RetroHexChat.Bots.Capability

  alias RetroHexChat.Bots.TemplateEngine

  @impl true
  @spec name() :: atom()
  def name, do: :greeter

  @impl true
  @spec description() :: String.t()
  def description, do: "Greet users on join, say goodbye on part"

  @impl true
  @spec handle_message(String.t(), String.t(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_message(_content, _author, _ctx), do: :ignore

  @impl true
  @spec handle_event(atom(), map(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_event(:user_joined, %{nickname: nickname}, ctx) do
    greeting = Map.get(ctx.config, "greeting", default_greeting())
    render_if_present(greeting, nickname, ctx)
  end

  def handle_event(:user_left, %{nickname: nickname}, ctx) do
    farewell = Map.get(ctx.config, "farewell")
    render_if_present(farewell, nickname, ctx)
  end

  def handle_event(_event, _payload, _ctx), do: :ignore

  @impl true
  @spec default_config() :: map()
  def default_config do
    %{"greeting" => default_greeting(), "farewell" => nil, "enabled" => true}
  end

  @impl true
  @spec validate_config(map()) :: :ok | {:error, String.t()}
  def validate_config(_), do: :ok

  @spec default_greeting() :: String.t()
  defp default_greeting, do: "Welcome, {nickname}!"

  @spec render_if_present(String.t() | nil, String.t(), map()) ::
          RetroHexChat.Bots.Capability.capability_result()
  defp render_if_present(nil, _nickname, _ctx), do: :ignore
  defp render_if_present("", _nickname, _ctx), do: :ignore

  defp render_if_present(template, nickname, ctx) do
    vars = %{
      "nickname" => nickname,
      "channel" => ctx.channel,
      "prefix" => ctx.command_prefix,
      "botname" => ctx.bot_name
    }

    {:reply, TemplateEngine.render(template, vars)}
  end
end
