defmodule RetroHexChat.Commands.Handlers.ClearWelcome do
  @moduledoc "Handler for /clearwelcome — operator clears channel welcome."
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, %{active_channel: nil}) do
    {:error, "You must be in a channel to use this command."}
  end

  def execute(_args, %{active_channel: channel} = context) do
    if channel in context.operator_in do
      {:ok, :ui_action, :clear_welcome, %{channel: channel}}
    else
      {:error, "Permission denied: you must be a channel operator."}
    end
  end

  @impl true
  @spec help() :: %{
          name: String.t(),
          syntax: String.t(),
          description: String.t(),
          examples: [String.t()]
        }
  def help do
    %{
      name: "clearwelcome",
      syntax: "/clearwelcome",
      description:
        "Clear the welcome message for the current channel. Requires operator privileges.",
      examples: ["/clearwelcome"]
    }
  end
end
