defmodule RetroHexChatWeb.ChatLive.ToolPost do
  @moduledoc """
  Where a picture made in a tool window — a drawing, a block of text art — is
  posted: one of the conversations the person is in, chosen by name.

  The window lists the channels joined and the private conversations open,
  the one on screen chosen first. What comes back from the form is checked
  against that same list, so a value edited in the page cannot post into a
  conversation the person is not in. Posting itself is the desktop's: the
  window sends `{:tool_post, target, text, opts}` up and the LiveView sends it
  the way it sends a recording (`CommandDispatch.send_to/5`).
  """

  alias RetroHexChat.Accounts.Session
  alias RetroHexChatWeb.ChatLive.CommandDispatch

  @typedoc "A conversation offered in the window, as the form names it and as it is shown."
  @type option :: %{value: String.t(), label: String.t()}

  @doc "The conversations to post into: channels first, then private conversations."
  @spec options(Session.t() | nil) :: [option()]
  def options(%Session{} = session) do
    Enum.map(session.channels, &%{value: "channel:" <> &1, label: &1}) ++
      Enum.map(session.pm_conversations, &%{value: "pm:" <> &1, label: &1})
  end

  def options(_session), do: []

  @doc "The conversation offered first: the one on screen, else the first one."
  @spec default(Session.t() | nil) :: String.t() | nil
  def default(%Session{active_pm: peer}) when is_binary(peer) and peer != "", do: "pm:" <> peer

  def default(%Session{active_channel: channel}) when is_binary(channel) and channel != "",
    do: "channel:" <> channel

  def default(session), do: session |> options() |> List.first() |> then(&(&1 && &1.value))

  @doc "The conversation a submitted value names, when it is one of `options/1`."
  @spec target(Session.t() | nil, String.t() | nil) :: {:ok, CommandDispatch.target()} | :error
  def target(session, value) do
    if Enum.any?(options(session), &(&1.value == value)) do
      case value do
        "channel:" <> channel -> {:ok, {:channel, channel}}
        "pm:" <> peer -> {:ok, {:pm, peer}}
      end
    else
      :error
    end
  end

  @doc "Hands the made thing to the desktop to send."
  @spec post(CommandDispatch.target(), String.t(), keyword()) :: :ok
  def post(target, text, opts) do
    send(self(), {:tool_post, target, text, opts})
    :ok
  end
end
