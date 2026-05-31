defmodule RetroHexChat.Commands.Handlers.SetWelcome do
  @moduledoc "Handler for /setwelcome <message> — operator sets channel welcome."
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, %{active_channel: nil}) do
    {:error, dgettext("commands", "You must be in a channel to use this command.")}
  end

  def execute([], %{active_channel: channel} = context) do
    if operator_or_owner?(channel, context) do
      {:ok, :ui_action, :clear_welcome, %{channel: channel}}
    else
      {:error, dgettext("commands", "Permission denied: you must be a channel operator.")}
    end
  end

  def execute(args, %{active_channel: channel} = context) do
    if operator_or_owner?(channel, context) do
      message = Enum.join(args, " ")
      {:ok, :ui_action, :set_welcome, %{channel: channel, message: message}}
    else
      {:error, dgettext("commands", "Permission denied: you must be a channel operator.")}
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
      name: "setwelcome",
      syntax: dgettext("commands", "/setwelcome <message>"),
      description:
        dgettext(
          "commands",
          "Set a message shown once to each user when they join the current channel.\nRequires: channel operator. Must be in a channel.\nWith no args: clears the welcome message (same as /clearwelcome)."
        ),
      examples: [dgettext("commands", "/setwelcome Welcome to our channel!")]
    }
  end

  defp operator_or_owner?(channel, context) do
    channel in context.operator_in
  end

  @impl true
  def category, do: :advanced

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "setwelcome",
      syntax: dgettext("commands", "/setwelcome <message>"),
      description:
        dgettext(
          "commands",
          "Set a message shown once to each user when they join the current channel."
        ),
      category: :advanced,
      parameters: [
        %Parameter{
          name: "message",
          required: true,
          type: :text,
          position: 0,
          description: dgettext("commands", "Channel welcome message")
        }
      ],
      examples: [dgettext("commands", "/setwelcome Welcome to our channel!")]
    }
  end
end
