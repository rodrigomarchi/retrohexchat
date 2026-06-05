defmodule RetroHexChatWeb.ChatLive.AdminConsoleEvents do
  @moduledoc """
  Handle Admin Console dialog events: open, close, execute batch commands, clear results.

  Commands are executed sequentially and context flows between them — e.g. `/join #general`
  updates `active_channel` so the next `/cs register` operates on `#general`.
  """

  import Phoenix.Component, only: [assign: 2]
  import RetroHexChatWeb.ChatLive.Helpers, only: [error_event: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.ServerRoles
  alias RetroHexChat.Channels.{Registry, Server, Supervisor}
  alias RetroHexChat.Commands.{Dispatcher, Parser}

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont | :halt, Phoenix.LiveView.Socket.t()}

  def handle_event("open_admin_console", _params, socket) do
    if admin?(socket) do
      {:halt,
       assign(socket,
         show_admin_console: true,
         admin_console_results: [],
         admin_console_tab: "console"
       )}
    else
      {:halt,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("close_admin_console", _params, socket) do
    {:halt, assign(socket, show_admin_console: false)}
  end

  def handle_event("admin_console_tab", %{"tab" => tab}, socket) do
    {:halt, assign(socket, admin_console_tab: normalize_tab(tab))}
  end

  def handle_event("execute_admin_console", %{"input" => input}, socket) do
    if admin?(socket) do
      results = execute_batch(input, socket)
      {:halt, assign(socket, admin_console_results: results)}
    else
      {:halt,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("clear_admin_console", _params, socket) do
    {:halt, assign(socket, admin_console_results: [])}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── Private ──────────────────────────────────────────────

  defp normalize_tab(tab)
       when tab in ~w(server_settings users channels motd broadcast audit_log turn danger_zone console),
       do: tab

  defp normalize_tab(_tab), do: "console"

  defp execute_batch(input, socket) do
    session = socket.assigns.session

    # Include active_channel in operator_in so /mode works on the initial channel.
    # Use empty channels list to bypass the per-user channel limit — the admin console
    # is a provisioning tool, not a real user session.
    initial_ops = if session.active_channel, do: [session.active_channel], else: []

    context = %{
      nickname: session.nickname,
      active_channel: session.active_channel,
      channels: [],
      identified: session.identified,
      owner_in: initial_ops,
      operator_in: initial_ops,
      half_operator_in: [],
      is_admin: true,
      is_server_operator: ServerRoles.server_operator?(session.nickname, session.identified)
    }

    lines =
      input
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(blank?(&1) or comment?(&1)))

    {results, _final_context} =
      Enum.map_reduce(lines, context, fn line, ctx ->
        {result_entry, new_ctx} = execute_line(line, ctx)
        {result_entry, new_ctx}
      end)

    results
  end

  defp execute_line(line, context) do
    case Parser.parse(line) do
      {:command, name, args} ->
        result = Dispatcher.dispatch(name, args, context)
        new_ctx = apply_side_effects(result, context)
        entry = %{line: line, status: result_status(result), message: result_message(result)}
        {entry, new_ctx}

      {:message, _text} ->
        entry = %{
          line: line,
          status: :error,
          message: dgettext("chat", "Not a command (must start with /)")
        }

        {entry, context}
    end
  end

  # When /join succeeds, actually join the channel server-side and update context
  defp apply_side_effects({:ok, :join, channel_name}, ctx) do
    do_join_channel(channel_name, ctx)
  end

  defp apply_side_effects({:ok, :join, channel_name, _password}, ctx) do
    do_join_channel(channel_name, ctx)
  end

  # When /topic set is dispatched, execute the topic change server-side
  defp apply_side_effects({:ok, :ui_action, :set_topic, %{channel: ch, topic: topic}}, ctx) do
    Server.set_topic(ch, ctx.nickname, topic)
    ctx
  end

  # When /mode is dispatched, execute the mode change server-side
  defp apply_side_effects(
         {:ok, :ui_action, :set_mode, %{channel: ch, mode_string: ms, params: params}},
         ctx
       ) do
    Server.set_mode(ch, ctx.nickname, ms, params)
    ctx
  end

  defp apply_side_effects(_result, ctx), do: ctx

  defp do_join_channel(channel_name, ctx) do
    ensure_channel_exists(channel_name)
    Server.join(channel_name, ctx.nickname, nil, identified: ctx.identified)

    %{
      ctx
      | active_channel: channel_name,
        channels: Enum.uniq([channel_name | ctx.channels]),
        owner_in: Enum.uniq([channel_name | ctx.owner_in]),
        operator_in: Enum.uniq([channel_name | ctx.operator_in])
    }
  end

  @spec ensure_channel_exists(String.t()) :: :ok | {:error, term()}
  defp ensure_channel_exists(channel_name) do
    case Registry.lookup(channel_name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> start_channel(channel_name)
    end
  end

  defp start_channel(channel_name) do
    case Supervisor.start_child(channel_name) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp result_status({:error, _}), do: :error
  defp result_status(_), do: :ok

  defp result_message({:ok, :system, %{content: text}}), do: text

  defp result_message({:ok, :join, channel}),
    do: dgettext("chat", "Joined %{channel}", channel: channel)

  defp result_message({:ok, :join, channel, _pw}),
    do: dgettext("chat", "Joined %{channel}", channel: channel)

  defp result_message({:ok, :ui_action, :set_topic, %{topic: t}}),
    do: dgettext("chat", "Topic set: %{topic}", topic: t)

  defp result_message({:ok, :ui_action, :set_mode, %{mode_string: m}}),
    do: dgettext("chat", "Mode set: %{mode}", mode: m)

  defp result_message({:ok, :ui_action, :view_topic, _}), do: dgettext("chat", "Done")
  defp result_message({:error, msg}), do: msg

  defp result_message({:ok, _type, payload}) when is_map(payload) do
    payload
    |> Map.get(:content, Map.get(payload, :message, dgettext("chat", "Done")))
    |> to_string()
  end

  defp result_message(_), do: dgettext("chat", "Done")

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
