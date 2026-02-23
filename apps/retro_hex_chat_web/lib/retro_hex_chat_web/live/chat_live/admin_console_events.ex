defmodule RetroHexChatWeb.ChatLive.AdminConsoleEvents do
  @moduledoc """
  Handle Admin Console dialog events: open, close, execute batch commands, clear results.
  """

  import Phoenix.Component, only: [assign: 2]
  import RetroHexChatWeb.ChatLive.Helpers, only: [error_event: 2]

  alias RetroHexChat.Accounts.ServerRoles
  alias RetroHexChat.Commands.{Dispatcher, Parser}

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont | :halt, Phoenix.LiveView.Socket.t()}

  def handle_event("open_admin_console", _params, socket) do
    if admin?(socket) do
      {:halt, assign(socket, show_admin_console: true, admin_console_results: [])}
    else
      {:halt, error_event(socket, "Admin Console is restricted to server administrators.")}
    end
  end

  def handle_event("close_admin_console", _params, socket) do
    {:halt, assign(socket, show_admin_console: false)}
  end

  def handle_event("execute_admin_console", %{"input" => input}, socket) do
    if admin?(socket) do
      results = execute_batch(input, socket)
      {:halt, assign(socket, admin_console_results: results)}
    else
      {:halt, error_event(socket, "Admin Console is restricted to server administrators.")}
    end
  end

  def handle_event("clear_admin_console", _params, socket) do
    {:halt, assign(socket, admin_console_results: [])}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── Private ──────────────────────────────────────────────

  defp execute_batch(input, socket) do
    session = socket.assigns.session

    context = %{
      nickname: session.nickname,
      active_channel: session.active_channel,
      channels: session.channels,
      identified: session.identified,
      operator_in: [],
      half_operator_in: [],
      is_admin: true,
      is_server_operator: ServerRoles.server_operator?(session.nickname, session.identified)
    }

    input
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(blank?(&1) or comment?(&1)))
    |> Enum.map(&execute_line(&1, context))
  end

  defp execute_line(line, context) do
    case Parser.parse(line) do
      {:command, name, args} ->
        result = Dispatcher.dispatch(name, args, context)
        %{line: line, status: result_status(result), message: result_message(result)}

      {:message, _text} ->
        %{line: line, status: :error, message: "Not a command (must start with /)"}
    end
  end

  defp result_status({:error, _}), do: :error
  defp result_status(_), do: :ok

  defp result_message({:ok, :system, %{content: text}}), do: text
  defp result_message({:error, msg}), do: msg

  defp result_message({:ok, _type, payload}) when is_map(payload) do
    payload |> Map.get(:content, Map.get(payload, :message, "Done")) |> to_string()
  end

  defp result_message(_), do: "Done"

  defp blank?(""), do: true
  defp blank?(_), do: false

  defp comment?("#" <> _), do: true
  defp comment?(_), do: false

  defp admin?(socket) do
    session = socket.assigns.session

    ServerRoles.admin?(session.nickname, session.identified) or
      ServerRoles.server_operator?(session.nickname, session.identified)
  end
end
