defmodule RetroHexChat.Bots.Capabilities.Placeholder do
  @moduledoc """
  A capability announced but not built yet: it shows in the bot's capability
  list with its description and default settings, accepts any settings, and
  answers no message and no event.

      use RetroHexChat.Bots.Capabilities.Placeholder,
        name: :script,
        description: dgettext("bots", "Custom script engine (Coming soon)"),
        default_config: %{"language" => "lua"}
  """

  @doc false
  defmacro __using__(opts) do
    name = Keyword.fetch!(opts, :name)
    description = Keyword.fetch!(opts, :description)
    default_config = Keyword.fetch!(opts, :default_config)

    quote do
      use RetroHexChat.Bots.Capability

      @impl true
      @spec name() :: atom()
      def name, do: unquote(name)

      @impl true
      @spec description() :: String.t()
      def description, do: unquote(description)

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
      def default_config, do: unquote(default_config)

      @impl true
      @spec validate_config(map()) :: :ok | {:error, String.t()}
      def validate_config(_config), do: :ok

      @impl true
      @spec commands() :: [%{trigger: String.t(), description: String.t()}]
      def commands, do: []
    end
  end
end
