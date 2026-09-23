defmodule RetroHexChat.Commands.Handlers.Unpin do
  @moduledoc "Handler for /unpin <message id>"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_args), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error,
     dgettext(
       "commands",
       "Which message? Use /unpin <id>, or unpin it from the Pinned window."
     )}
  end

  def execute([raw_id | _rest], context) do
    case context.active_channel do
      nil ->
        {:error, dgettext("commands", "You are not in any channel")}

      channel ->
        with {:ok, id} <- parse_id(raw_id) do
          {:ok, :ui_action, :unpin_message, %{channel: channel, message_id: id}}
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
      name: "unpin",
      syntax: dgettext("commands", "/unpin <message id>"),
      description:
        dgettext(
          "commands",
          "Stop keeping a message in view. The message itself stays where it is — only the pin goes.\nOperators only."
        ),
      examples: ["/unpin 1284"]
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
      command: "unpin",
      syntax: dgettext("commands", "/unpin <message id>"),
      description: dgettext("commands", "Stop keeping a message in view."),
      category: :channel,
      parameters: [
        %Parameter{
          name: "message id",
          required: true,
          type: :text,
          position: 0,
          description: dgettext("commands", "Id of the message to stop keeping")
        }
      ],
      examples: ["/unpin 1284"]
    }
  end
end
