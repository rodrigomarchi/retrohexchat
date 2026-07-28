defmodule RetroHexChatWeb.ChatLive.Components.AdminConsoleDialog do
  @moduledoc """
  Stateful island for the Admin Console window — the batch command runner.

  Owns the transcript and executes each submitted line. Mounted inside a
  server-managed window: presence in the DOM means open, so closing unmounts
  the island and the transcript goes with it.

  The context it runs under is deliberately fabricated rather than the caller's
  real session: `is_admin` is forced true and the channel list is emptied so the
  per-user channel limit does not apply. This is a provisioning tool, not a user
  session — but that also means `AdminOps.admin?/1` is the only thing standing
  between a caller and privileged execution.

  Side effects the dispatcher only describes (joining, topic, modes) are applied
  here for real, because a script that says it joined a channel has to have
  joined it.
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.AdminConsoleDialog

  alias RetroHexChat.Accounts.ServerRoles
  alias RetroHexChat.Channels.{Registry, Server, Supervisor}
  alias RetroHexChat.Commands.{Dispatcher, Parser}
  alias RetroHexChatWeb.ChatLive.AdminOps

  @id "admin-console-dialog"

  # The console transcript is an ephemeral session buffer, not a database list:
  # there is nothing older to page back to, so it takes a cap rather than
  # pagination. Without one it grew for the lifetime of the session, and the
  # `++` append made every run cost more than the last.
  @max_results 200

  @spec id() :: String.t()
  def id, do: @id

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, socket |> assign(:id, @id) |> assign(results: [], dropped: 0, session: nil)}
  end

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("admin_console_run", %{"input" => input}, socket) do
    if AdminOps.admin?(socket) do
      combined = socket.assigns.results ++ execute_batch(input, socket)
      results = cap(combined)

      # Once a line scrolls off the top of the transcript it is gone, so the
      # count is the only remaining evidence it was ever run.
      dropped = socket.assigns.dropped + max(length(combined) - length(results), 0)

      {:noreply, assign(socket, results: results, dropped: dropped)}
    else
      {:noreply, AdminOps.error_event(socket, AdminOps.restricted_message())}
    end
  end

  def handle_event("admin_console_clear", _params, socket) do
    if AdminOps.admin?(socket) do
      # Clearing the transcript clears the record of what fell off it too.
      {:noreply, assign(socket, results: [], dropped: 0)}
    else
      {:noreply, AdminOps.error_event(socket, AdminOps.restricted_message())}
    end
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.admin_console_panel
        id={@id}
        target={@myself}
        results={@results}
        dropped={@dropped}
        on_run="admin_console_run"
        on_clear="admin_console_clear"
      />
    </div>
    """
  end

  # ── Batch execution ──────────────────────────────────────────────

  defp execute_batch(input, socket) do
    session = socket.assigns.session

    # Seed operator rights on the current channel so /mode works there, and
    # empty the channel list to bypass the per-user limit — provisioning a
    # server routinely joins more channels than a person is allowed.
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

    {results, _final_context} = Enum.map_reduce(lines, context, &execute_line/2)
    results
  end

  defp execute_line(line, context) do
    case Parser.parse(line) do
      {:command, name, args} ->
        result = Dispatcher.dispatch(name, args, context)

        entry = %{
          line: line,
          status: AdminOps.result_status(result),
          message: AdminOps.result_message(result)
        }

        {entry, apply_side_effects(result, context)}

      {:message, _text} ->
        entry = %{
          line: line,
          status: :error,
          message: dgettext("chat", "Not a command (must start with /)")
        }

        {entry, context}
    end
  end

  # ── Side effects ─────────────────────────────────────────────────
  #
  # The dispatcher reports what a command means; for a script to be real, some
  # of it has to actually happen.

  defp apply_side_effects({:ok, :join, channel_name}, ctx), do: do_join_channel(channel_name, ctx)

  defp apply_side_effects({:ok, :join, channel_name, _password}, ctx) do
    do_join_channel(channel_name, ctx)
  end

  defp apply_side_effects({:ok, :ui_action, :set_topic, %{channel: ch, topic: topic}}, ctx) do
    Server.set_topic(ch, ctx.nickname, topic)
    ctx
  end

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

  defp blank?(""), do: true
  defp blank?(_), do: false

  defp comment?("#" <> _), do: true
  defp comment?(_), do: false

  # Keeps the most recent results; older ones fall off the top.
  @spec cap([map()]) :: [map()]
  defp cap(results) do
    case length(results) - @max_results do
      excess when excess > 0 -> Enum.drop(results, excess)
      _ -> results
    end
  end
end
