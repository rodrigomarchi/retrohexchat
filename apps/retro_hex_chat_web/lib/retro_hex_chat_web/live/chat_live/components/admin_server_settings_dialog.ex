defmodule RetroHexChatWeb.ChatLive.Components.AdminServerSettingsDialog do
  @moduledoc """
  Stateful island for the Admin Server Settings window.

  Owns the settings values behind the form, the two read-only report panes and
  the outcome strip. Mounted inside a server-managed window: presence in the DOM
  means open, so closing unmounts the island.

  Saving diffs the submitted form against the values loaded at open time and
  dispatches one `admin server set` per changed key — so an unchanged field is
  never rewritten, and the strip reports every line the server answered.
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.AdminServerSettingsDialog

  alias RetroHexChat.Admin
  alias RetroHexChatWeb.ChatLive.{AdminOps, ChatContext}

  @id "admin-server-settings-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @initial %{
    info: nil,
    settings_text: nil,
    values: %{},
    result: nil,
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
      {:ok, socket |> assign(loaded?: true) |> assign_snapshot(nil)}
    end
  end

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("admin_server_settings_refresh", _params, socket) do
    guarded(socket, fn -> {:noreply, assign_snapshot(socket, nil)} end)
  end

  def handle_event("admin_server_settings_save", params, socket) do
    guarded(socket, fn ->
      changes = Admin.server_setting_changes(socket.assigns.values, submitted(params))
      {:noreply, assign_snapshot(socket, save(changes, socket))}
    end)
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns = assign(assigns, can_edit: ChatContext.admin_only?(assigns.session))

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.admin_server_settings_panel
        id={@id}
        target={@myself}
        info={@info}
        settings_text={@settings_text}
        values={@values}
        result={@result}
        can_edit={@can_edit}
        on_save="admin_server_settings_save"
        on_refresh="admin_server_settings_refresh"
      />
    </div>
    """
  end

  defp guarded(socket, run) do
    if AdminOps.admin?(socket) do
      run.()
    else
      {:noreply, AdminOps.error_event(socket, AdminOps.restricted_message())}
    end
  end

  defp assign_snapshot(socket, result) do
    info = AdminOps.dispatch(socket, "admin", ["server", "info"])
    settings = AdminOps.dispatch(socket, "admin", ["server", "settings"])

    assign(socket,
      info: AdminOps.result_message(info),
      settings_text: AdminOps.result_message(settings),
      values: Admin.server_settings_values(),
      result: result || AdminOps.first_error_entry([info, settings])
    )
  end

  # Only the known setting keys, as strings — a form post carries more than the
  # record does.
  defp submitted(params) do
    params
    |> Map.take(Admin.server_setting_keys())
    |> Map.new(fn {key, value} -> {key, to_string(value)} end)
  end

  defp save([], _socket) do
    %{status: :ok, message: dgettext("chat", "No server settings changed.")}
  end

  defp save(changes, socket) do
    results =
      Enum.map(changes, fn {key, value} ->
        AdminOps.dispatch(socket, "admin", ["server", "set", key, value])
      end)

    %{
      status:
        if(Enum.any?(results, &(AdminOps.result_status(&1) == :error)), do: :error, else: :ok),
      message: Enum.map_join(results, "\n", &AdminOps.result_message/1)
    }
  end
end
