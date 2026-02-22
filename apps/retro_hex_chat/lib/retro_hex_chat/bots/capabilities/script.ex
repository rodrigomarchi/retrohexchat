defmodule RetroHexChat.Bots.Capabilities.Script do
  @moduledoc "Custom script engine (Coming soon)"
  @behaviour RetroHexChat.Bots.Capability

  @impl true
  @spec name() :: atom()
  def name, do: :script

  @impl true
  @spec description() :: String.t()
  def description, do: "Custom script engine (Coming soon)"

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
    %{"language" => "lua", "source" => "", "sandbox" => true, "timeout_ms" => 5000}
  end

  @impl true
  @spec validate_config(map()) :: :ok | {:error, String.t()}
  def validate_config(_config), do: :ok

  @impl true
  @spec commands() :: [%{trigger: String.t(), description: String.t()}]
  def commands, do: []
end
