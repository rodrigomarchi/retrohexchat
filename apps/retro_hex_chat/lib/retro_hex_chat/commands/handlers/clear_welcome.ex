defmodule RetroHexChat.Commands.Handlers.ClearWelcome do
  @moduledoc "Handler for /clearwelcome — operator clears channel welcome."
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, %{active_channel: nil}) do
    {:error, gettext("You must be in a channel to use this command.")}
  end

  def execute(_args, %{active_channel: channel} = context) do
    if channel in context.operator_in do
      {:ok, :ui_action, :clear_welcome, %{channel: channel}}
    else
      {:error, gettext("Permission denied: you must be a channel operator.")}
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
        gettext(
          "Remove the welcome message from the current channel so new joiners won't see one.\nRequires: channel operator. Must be in a channel."
        ),
      examples: ["/clearwelcome"]
    }
  end

  @impl true
  def category, do: :advanced

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax

    %CommandSyntax{
      command: "clearwelcome",
      syntax: "/clearwelcome",
      description:
        gettext(
          "Remove the welcome message from the current channel so new joiners won't see one."
        ),
      category: :advanced,
      parameters: [],
      examples: ["/clearwelcome"]
    }
  end
end
