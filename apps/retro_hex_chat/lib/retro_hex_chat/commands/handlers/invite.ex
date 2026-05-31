defmodule RetroHexChat.Commands.Handlers.Invite do
  @moduledoc "Handler for /invite <nickname> [#channel]"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error, gettext("Usage: /invite <nickname> [#channel]")}
  end

  def execute(["auto"], _context) do
    {:ok, :ui_action, :toggle_auto_join_on_invite, %{}}
  end

  def execute([nickname], context) do
    with {:ok, channel} <- require_channel(context) do
      {:ok, :ui_action, :send_invite, %{target: nickname, channel: channel}}
    end
  end

  def execute([nickname, channel], _context) do
    {:ok, :ui_action, :send_invite, %{target: nickname, channel: channel}}
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
      name: "invite",
      syntax: gettext("/invite <nickname> [#channel]"),
      description:
        gettext(
          "Send a channel invitation to another user. Required for invite-only (+i) channels.\nDefaults to current channel if no #channel specified. Must be in a channel when no channel arg given.\n/invite auto — toggles whether you automatically join channels when invited."
        ),
      examples: [
        gettext("/invite Alice"),
        gettext("/invite Alice #private"),
        gettext("/invite auto")
      ]
    }
  end

  @spec require_channel(Handler.context()) :: {:ok, String.t()} | {:error, String.t()}
  defp require_channel(%{active_channel: nil}),
    do: {:error, gettext("You are not in any channel")}

  defp require_channel(%{active_channel: channel}), do: {:ok, channel}

  @impl true
  def category, do: :channel

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "invite",
      syntax: gettext("/invite <nickname> [#channel]"),
      description:
        gettext(
          "Send a channel invitation to another user. Required for invite-only (+i) channels.\nDefaults to current channel if no #channel specified. Must be in a channel when no channel arg given.\n/invite auto — toggles whether you automatically join channels when invited."
        ),
      category: :channel,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: gettext("User to invite")
        },
        %Parameter{
          name: "#channel",
          required: false,
          type: :channel,
          position: 1,
          description: gettext("Target channel (defaults to current channel)")
        }
      ],
      examples: [
        gettext("/invite Alice"),
        gettext("/invite Alice #private"),
        gettext("/invite auto")
      ]
    }
  end
end
