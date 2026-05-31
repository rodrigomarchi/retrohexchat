defmodule RetroHexChat.Commands.Handlers.Unban do
  @moduledoc "Handler for /unban <nickname>"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error, gettext("Usage: /unban <nickname>")}
  end

  def execute([target | _rest], context) do
    with {:ok, channel} <- require_channel(context),
         :ok <- require_operator(context, channel) do
      {:ok, :ui_action, :unban_user, %{channel: channel, target: target}}
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
      name: "unban",
      syntax: gettext("/unban <nickname>"),
      description:
        gettext(
          "Remove a ban from a user, allowing them to rejoin the channel.\nRequires: channel operator. Must be in a channel."
        ),
      examples: [gettext("/unban user123")]
    }
  end

  defp require_channel(%{active_channel: nil}),
    do: {:error, gettext("You are not in any channel")}

  defp require_channel(%{active_channel: channel}), do: {:ok, channel}

  defp require_operator(%{operator_in: operator_in}, channel) do
    if channel in operator_in do
      :ok
    else
      {:error, gettext("You must be a channel operator to unban users")}
    end
  end

  @impl true
  def category, do: :channel

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "unban",
      syntax: gettext("/unban <nickname>"),
      description: gettext("Remove a ban from a user, allowing them to rejoin the channel."),
      category: :channel,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: gettext("User to unban")
        }
      ],
      examples: [gettext("/unban user123")]
    }
  end
end
