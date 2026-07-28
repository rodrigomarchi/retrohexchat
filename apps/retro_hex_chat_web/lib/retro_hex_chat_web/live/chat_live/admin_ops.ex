defmodule RetroHexChatWeb.ChatLive.AdminOps do
  @moduledoc """
  Privileged-command plumbing shared by the admin windows.

  Every admin window runs the same shape of work: confirm the caller still holds
  the role, dispatch a command under a server-scoped context, and turn the
  dispatcher's reply into the `%{status:, message:}` entry the window renders in
  its inline result strip. That substrate lives here so each window module holds
  only its own domain.

  Failures that belong to the chat surface rather than to a window bubble
  through `error_event/2`; the host LiveView renders them as a system line.
  """
  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.ServerRoles
  alias RetroHexChat.Commands.Dispatcher

  @doc """
  Whether the session may operate the admin windows.

  Server operators count. They see a narrower set of enabled controls than a
  full admin, but opening the window is theirs.
  """
  @spec admin?(Phoenix.LiveView.Socket.t()) :: boolean()
  def admin?(socket) do
    session = socket.assigns.session

    ServerRoles.admin?(session.nickname, session.identified) or
      ServerRoles.server_operator?(session.nickname, session.identified)
  end

  @doc "The refusal shown when a non-admin reaches an admin window's handler."
  @spec restricted_message() :: String.t()
  def restricted_message do
    dgettext("chat", "Admin tools are restricted to server administrators.")
  end

  @doc """
  Dispatch a command under the caller's privileged context.

  Channel roles are deliberately blank in that context: admin commands are
  server-scoped and must not inherit the caller's per-channel privileges.
  """
  @spec dispatch(Phoenix.LiveView.Socket.t(), String.t(), [String.t()]) :: term()
  def dispatch(socket, command, args) do
    Dispatcher.dispatch(command, args, user_context(socket))
  end

  @doc "Privileged dispatch context for the session driving an admin window."
  @spec user_context(Phoenix.LiveView.Socket.t()) :: map()
  def user_context(socket) do
    session = socket.assigns.session

    %{
      nickname: session.nickname,
      active_channel: session.active_channel,
      channels: session.channels,
      identified: session.identified,
      owner_in: [],
      operator_in: [],
      half_operator_in: [],
      is_admin: ServerRoles.admin?(session.nickname, session.identified),
      is_server_operator: ServerRoles.server_operator?(session.nickname, session.identified)
    }
  end

  @doc "Dispatcher reply as the entry an inline result strip renders."
  @spec result_entry(term()) :: %{status: :ok | :error, message: String.t()}
  def result_entry(result) do
    %{status: result_status(result), message: result_message(result)}
  end

  @doc "The first failing reply in a batch as a result entry, or nil if all succeeded."
  @spec first_error_entry([term()]) :: %{status: :ok | :error, message: String.t()} | nil
  def first_error_entry(results) do
    results
    |> Enum.find(&(result_status(&1) == :error))
    |> case do
      nil -> nil
      result -> result_entry(result)
    end
  end

  @doc "Whether a dispatcher reply reports failure."
  @spec result_status(term()) :: :ok | :error
  def result_status({:error, _}), do: :error
  def result_status(_), do: :ok

  @doc """
  The structured listing a dispatcher reply carries, or nil.

  A listing command answers with both halves — the text the chat prints and the
  table a window renders. Windows that have been converted read this; the rest
  keep reading `result_message/1`.
  """
  @spec result_table(term()) :: RetroHexChat.Admin.Table.t() | nil
  def result_table({:ok, _type, %{table: %RetroHexChat.Admin.Table{} = table}}), do: table
  def result_table(_result), do: nil

  @doc "Human-readable line for a dispatcher reply."
  @spec result_message(term()) :: String.t()
  def result_message({:ok, :system, %{content: text}}), do: text

  def result_message({:ok, :join, channel}),
    do: dgettext("chat", "Joined %{channel}", channel: channel)

  def result_message({:ok, :join, channel, _pw}),
    do: dgettext("chat", "Joined %{channel}", channel: channel)

  def result_message({:ok, :ui_action, :set_topic, %{topic: t}}),
    do: dgettext("chat", "Topic set: %{topic}", topic: t)

  def result_message({:ok, :ui_action, :set_mode, %{mode_string: m}}),
    do: dgettext("chat", "Mode set: %{mode}", mode: m)

  def result_message({:ok, :ui_action, :show_motd, %{content: text}}), do: text

  def result_message({:ok, :ui_action, :view_topic, _}), do: dgettext("chat", "Done")
  def result_message({:error, msg}), do: msg

  def result_message({:ok, _type, payload}) when is_map(payload) do
    payload
    |> Map.get(:content, Map.get(payload, :message, dgettext("chat", "Done")))
    |> to_string()
  end

  def result_message(_), do: dgettext("chat", "Done")

  @doc """
  Bubble a system line to the chat surface and return the socket unchanged.

  The host LiveView owns the chat log, so a window that needs to say something
  there sends rather than assigns.
  """
  @spec error_event(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def error_event(socket, message) do
    send(self(), {:admin_system_error, message})
    socket
  end
end
