defmodule RetroHexChat.Commands.Handlers.Pin do
  @moduledoc "Handler for /pin <message id>"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_args), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  # The id rather than "the last message": the command is for keeping a line
  # somebody has scrolled back to find, and that line is rarely the newest one.
  def execute([], _context) do
    {:error,
     dgettext("commands", "Which message? Use /pin <id>, or pin it from its right-click menu.")}
  end

  def execute([raw_id | _rest], context) do
    case context.active_channel do
      nil ->
        {:error, dgettext("commands", "You are not in any channel")}

      channel ->
        with {:ok, id} <- parse_id(raw_id) do
          {:ok, :ui_action, :pin_message, %{channel: channel, message_id: id}}
        end
    end
  end

  defp parse_id(raw) do
    case Integer.parse(String.trim(raw)) do
      {id, ""} when id > 0 -> {:ok, id}
      _other -> {:error, dgettext("commands", "That is not a message id")}
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
      name: "pin",
      syntax: dgettext("commands", "/pin <message id>"),
      description:
        dgettext(
          "commands",
          "Keep a message in view for the whole channel — the rules, a link, what was agreed.\nPinned messages are listed in the Pinned window and stay findable after they scroll away.\nOperators only. A channel keeps up to 50."
        ),
      examples: ["/pin 1284"]
    }
  end

  @impl true
  def category, do: :channel

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "pin",
      syntax: dgettext("commands", "/pin <message id>"),
      description: dgettext("commands", "Keep a message in view for the whole channel."),
      category: :channel,
      parameters: [
        %Parameter{
          name: "message id",
          required: true,
          type: :text,
          position: 0,
          description: dgettext("commands", "Id of the message to keep")
        }
      ],
      examples: ["/pin 1284"]
    }
  end
end
