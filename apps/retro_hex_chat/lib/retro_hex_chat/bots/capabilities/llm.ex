defmodule RetroHexChat.Bots.Capabilities.LLM do
  use Gettext, backend: RetroHexChat.Gettext
  @moduledoc "LLM-powered intelligent responses (Coming soon)"
  @behaviour RetroHexChat.Bots.Capability

  @impl true
  @spec name() :: atom()
  def name, do: :llm

  @impl true
  @spec description() :: String.t()
  def description, do: gettext("LLM-powered intelligent responses (Coming soon)")

  @impl true
  @spec handle_message(String.t(), String.t(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_message(_content, _author, _ctx), do: :ignore

  @impl true
  @spec handle_event(atom(), map(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_event(_event, _payload, _ctx), do: :ignore

  @impl true
  @spec default_config() :: map()
  def default_config do
    %{
      "provider" => nil,
      "model" => nil,
      "system_prompt" => "",
      "max_tokens" => 150,
      "temperature" => 0.7
    }
  end

  @impl true
  @spec validate_config(map()) :: :ok | {:error, String.t()}
  def validate_config(_config), do: :ok

  @impl true
  @spec commands() :: [%{trigger: String.t(), description: String.t()}]
  def commands, do: []
end
