defmodule RetroHexChatWeb.ChatLive.Components.AdminChannelsDialog do
  @moduledoc """
  Stateful island for the Admin Channels window.

  Owns the channel list and ban list text, the search filter, the info and
  create drafts, the last action's result strip, and every privileged
  `admin channel …` / `admin cs …` dispatch. Mounted inside a server-managed
  window: presence in the DOM means open, so closing unmounts the island.

  The channel typed into the info form doubles as the ban-list selector — the
  ban list only loads for a named channel, and stays in step with it.

  Permission flags are derived from the passthrough `session` in `render/1`.
  They only disable controls; the handlers re-check with `AdminOps.admin?/1`,
  which is the actual authorization.
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.AdminChannelsDialog

  alias RetroHexChatWeb.ChatLive.{AdminOps, ChatContext}

  @id "admin-channels-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @initial %{
    channels_text: nil,
    channels_table: nil,
    channels_banlist_text: nil,
    channels_result: nil,
    channels_search: "",
    channels_info_channel: "",
    channels_create_name: "",
    loaded?: false
  }

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, socket |> assign(:id, @id) |> assign(@initial) |> assign(session: nil)}
  end

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if socket.assigns.loaded? do
      {:ok, socket}
    else
      {:ok, socket |> assign(loaded?: true) |> assign_snapshot(%{}, nil)}
    end
  end

  # ── Registry ─────────────────────────────────────────────────────

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("admin_channels_refresh", params, socket) do
    guarded(socket, fn -> {:noreply, assign_snapshot(socket, params, nil)} end)
  end

  def handle_event("admin_channels_info", %{"channel" => channel}, socket) do
    guarded(socket, fn ->
      channel = trim(channel)

      result =
        if channel == "" do
          error_result(dgettext("chat", "Enter a channel to inspect."))
        else
          dispatch(socket, ["channel", "info", channel])
        end

      {:noreply, assign_snapshot(socket, %{"info_channel" => channel}, result)}
    end)
  end

  def handle_event("admin_channels_create", %{"channel" => channel}, socket) do
    guarded(socket, fn ->
      channel = trim(channel)

      result =
        if channel == "" do
          error_result(dgettext("chat", "Enter a channel to create."))
        else
          dispatch(socket, ["channel", "create", channel])
        end

      {:noreply, assign_snapshot(socket, %{"create_channel" => channel}, result)}
    end)
  end

  # ── Destructive ──────────────────────────────────────────────────

  def handle_event("admin_channels_delete", params, socket) do
    destructive(socket, "delete", params)
  end

  def handle_event("admin_channels_purge", params, socket) do
    destructive(socket, "purge", params)
  end

  # ── ChanServ ─────────────────────────────────────────────────────

  def handle_event("admin_channels_cs_info", params, socket) do
    chanserv(socket, params, fn -> cs_simple_result(socket, "info", params) end)
  end

  def handle_event("admin_channels_cs_access_list", params, socket) do
    chanserv(socket, params, fn -> cs_access_list_result(socket, params) end)
  end

  def handle_event("admin_channels_cs_transfer", params, socket) do
    chanserv(socket, params, fn -> cs_transfer_result(socket, params) end)
  end

  def handle_event("admin_channels_cs_access_add", params, socket) do
    chanserv(socket, params, fn -> cs_access_result(socket, "add", params) end)
  end

  def handle_event("admin_channels_cs_access_del", params, socket) do
    chanserv(socket, params, fn -> cs_access_result(socket, "del", params) end)
  end

  def handle_event("admin_channels_cs_drop", params, socket) do
    # A dropped registration makes the previously inspected channel stale, so
    # the snapshot reloads with no channel selected.
    chanserv(socket, %{"info_channel" => ""}, fn -> cs_drop_result(socket, params) end)
  end

  # ── Render ───────────────────────────────────────────────────────

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns = assign(assigns, can_refresh: ChatContext.admin_only?(assigns.session))

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.admin_channels_panel
        id={@id}
        target={@myself}
        text={@channels_text}
        table={@channels_table}
        banlist_text={@channels_banlist_text}
        result={@channels_result}
        search={@channels_search}
        info_channel={@channels_info_channel}
        create_name={@channels_create_name}
        can_refresh={@can_refresh}
        on_refresh="admin_channels_refresh"
        on_info="admin_channels_info"
        on_create="admin_channels_create"
        on_delete="admin_channels_delete"
        on_purge="admin_channels_purge"
        on_cs_info="admin_channels_cs_info"
        on_cs_drop="admin_channels_cs_drop"
        on_cs_transfer="admin_channels_cs_transfer"
        on_cs_access_list="admin_channels_cs_access_list"
        on_cs_access_add="admin_channels_cs_access_add"
        on_cs_access_del="admin_channels_cs_access_del"
      />
    </div>
    """
  end

  # ── Authorization ────────────────────────────────────────────────

  defp guarded(socket, run) do
    if AdminOps.admin?(socket) do
      run.()
    else
      {:noreply, AdminOps.error_event(socket, AdminOps.restricted_message())}
    end
  end

  defp destructive(socket, action, params) do
    guarded(socket, fn ->
      channel = param(params, "channel")
      result = destructive_result(socket, action, channel, params)

      # Deleting the channel invalidates the inspected one; purging does not.
      selected = if action == "delete", do: "", else: channel

      {:noreply, assign_snapshot(socket, %{"info_channel" => selected}, result)}
    end)
  end

  defp chanserv(socket, snapshot_params, result_fun) do
    guarded(socket, fn ->
      {:noreply, assign_snapshot(socket, snapshot_params(snapshot_params), result_fun.())}
    end)
  end

  defp snapshot_params(%{"info_channel" => _channel} = params), do: params
  defp snapshot_params(params), do: %{"info_channel" => Map.get(params, "channel", "")}

  # ── Snapshot ─────────────────────────────────────────────────────

  defp assign_snapshot(socket, params, result) do
    search = draft(socket, params, "search", :channels_search)
    info_channel = draft(socket, params, "info_channel", :channels_info_channel)
    create_name = draft(socket, params, "create_channel", :channels_create_name)

    list = AdminOps.dispatch(socket, "admin", ["channel", "list"] ++ search_args(search))
    banlist = banlist_result(socket, info_channel)

    assign(socket,
      channels_text: AdminOps.result_message(list),
      channels_table: AdminOps.result_table(list),
      channels_banlist_text: banlist_text(banlist),
      channels_search: search,
      channels_info_channel: info_channel,
      channels_create_name: create_name,
      channels_result: result || AdminOps.first_error_entry([list, banlist])
    )
  end

  # A submitted form supplies its own field; anything else keeps what the window
  # already shows, so an action never silently widens or clears the filter.
  defp draft(socket, params, key, assign_key) do
    case Map.fetch(params, key) do
      {:ok, value} -> trim(value)
      :error -> trim(Map.fetch!(socket.assigns, assign_key))
    end
  end

  defp search_args(""), do: []
  defp search_args(search), do: ["--search", search]

  defp banlist_result(_socket, ""), do: nil
  defp banlist_result(socket, channel), do: dispatch_raw(socket, ["channel", "banlist", channel])

  defp banlist_text(nil), do: ""
  defp banlist_text(result), do: AdminOps.result_message(result)

  # ── Action results ───────────────────────────────────────────────

  defp destructive_result(_socket, _action, "", _params) do
    error_result(dgettext("chat", "Enter a channel for this action."))
  end

  defp destructive_result(socket, action, channel, params) do
    case confirmation(channel, params) do
      :ok -> dispatch(socket, destructive_args(action, channel, params))
      error -> error
    end
  end

  defp destructive_args("delete", channel, _params), do: ["channel", "delete", channel]

  defp destructive_args("purge", channel, params) do
    ["channel", "purge", channel] ++ from_args(params)
  end

  defp cs_simple_result(socket, action, params) do
    with {:ok, channel} <- require_channel(params) do
      dispatch(socket, ["cs", action, channel])
    end
  end

  defp cs_access_list_result(socket, params) do
    with {:ok, channel} <- require_channel(params) do
      dispatch(socket, ["cs", "access", channel])
    end
  end

  defp cs_transfer_result(socket, params) do
    with {:ok, channel} <- require_channel(params),
         {:ok, nick} <- require_nick(params) do
      dispatch(socket, ["cs", "transfer", channel, nick])
    end
  end

  defp cs_access_result(socket, action, params) do
    with {:ok, channel} <- require_channel(params),
         {:ok, nick} <- require_nick(params),
         {:ok, level} <- require_level(params) do
      dispatch(socket, ["cs", "access", channel, action, level, nick])
    end
  end

  defp cs_drop_result(socket, params) do
    with {:ok, channel} <- require_channel(params),
         :ok <- confirmation(channel, params) do
      dispatch(socket, ["cs", "drop", channel])
    end
  end

  # ── Required fields ──────────────────────────────────────────────
  #
  # Each returns `{:ok, value}` or a result entry, so a `with` chain short
  # circuits straight into the strip the window renders.

  defp require_channel(params) do
    required(params, "channel", dgettext("chat", "Enter a channel for this action."))
  end

  defp require_nick(params) do
    required(params, "nick", dgettext("chat", "Enter a nick for this action."))
  end

  defp require_level(params) do
    required(params, "level", dgettext("chat", "Choose an access level."))
  end

  defp required(params, key, message) do
    case param(params, key) do
      "" -> error_result(message)
      value -> {:ok, value}
    end
  end

  defp confirmation(channel, params) do
    if param(params, "confirm") == channel do
      :ok
    else
      error_result(dgettext("chat", "Type the channel name to confirm."))
    end
  end

  # ── Dispatch + params ────────────────────────────────────────────

  defp dispatch(socket, args), do: socket |> dispatch_raw(args) |> AdminOps.result_entry()

  defp dispatch_raw(socket, args), do: AdminOps.dispatch(socket, "admin", args)

  defp from_args(params) do
    case param(params, "from") do
      "" -> []
      from -> ["--from", from]
    end
  end

  defp param(params, key), do: params |> Map.get(key, "") |> trim()

  defp trim(value), do: value |> to_string() |> String.trim()

  defp error_result(message), do: %{status: :error, message: message}
end
