defmodule RetroHexChatWeb.ChatLive.Components.IgnoreListDialog do
  @moduledoc """
  Stateful island for the Ignore List window — the ignored nicknames with their
  scope and expiry, plus the add sub-form modal.

  Mounted inside a server-managed desktop window: closing unmounts the island,
  resetting the selection and any open sub-form. The `IgnoreList` mutations run
  here and produce a new `session`; the parent owns `session` and the expiry
  timers, so the work bubbles up:

    * `{:ab_session, session, :ignore}` — parent assigns + persists.
    * `{:ab_status, level, msg}` — chat-surface status / error lines.
    * `{:ab_ignore_timer, op, ...}` — the parent owns the ignore debounce timers.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.IgnoreListDialog
  import RetroHexChatWeb.ChatLive.Helpers, only: [parse_dialog_duration: 1]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.IgnoreList

  @id "ignore-list-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @initial %{selected: nil, show_add_dialog: false}

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, socket |> assign(:id, @id) |> assign(@initial) |> assign(session: nil)}
  end

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("control_select", %{"nickname" => nick}, socket) do
    {:noreply, assign(socket, selected: nick)}
  end

  def handle_event("control_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_add_dialog: true)}
  end

  def handle_event("control_add_cancel", _params, socket) do
    {:noreply, assign(socket, show_add_dialog: false)}
  end

  def handle_event("control_add_confirm", params, socket) do
    nick = params["nickname"]
    type = String.to_existing_atom(params["type"])
    duration_str = params["duration"]
    session = socket.assigns.session

    cond do
      String.downcase(String.trim(nick)) == String.downcase(session.nickname) ->
        {:noreply,
         bubble_status(socket, :error_event, dgettext("chat", "You cannot ignore yourself"))}

      duration_str not in [nil, ""] and match?({nil, nil}, parse_dialog_duration(duration_str)) ->
        {:noreply,
         bubble_status(
           socket,
           :error_event,
           dgettext("chat", "Invalid duration format. Use: 5m, 2h, or 1d")
         )}

      true ->
        {duration, expires_at} = parse_dialog_duration(duration_str)

        case IgnoreList.add_entry(session.ignore_list, nick, type, expires_at) do
          {:ok, updated_list} ->
            send(self(), {:ab_ignore_timer, :restart, nick, duration})

            {:noreply,
             socket
             |> assign(show_add_dialog: false)
             |> put_session(Session.set_ignore_list(session, updated_list))
             |> bubble_status(
               :system_event,
               dgettext("chat", "* %{nickname} is now ignored (%{type})",
                 nickname: nick,
                 type: ignore_type_label(type)
               )
             )}

          {:error, reason} ->
            {:noreply,
             bubble_status(
               socket,
               :error_event,
               dgettext("chat", "Failed to add ignore: %{reason}", reason: reason)
             )}
        end
    end
  end

  def handle_event("control_remove", _params, socket) do
    nick = socket.assigns.selected
    session = socket.assigns.session

    with true <- nick != nil,
         {:ok, updated_list} <- IgnoreList.remove_entry(session.ignore_list, nick) do
      send(self(), {:ab_ignore_timer, :remove, nick})

      {:noreply,
       socket
       |> assign(selected: nil)
       |> put_session(Session.set_ignore_list(session, updated_list))
       |> bubble_status(
         :system_event,
         dgettext("chat", "* %{nickname} is no longer ignored", nickname: nick)
       )}
    else
      _ -> {:noreply, socket}
    end
  end

  # ── Render ───────────────────────────────────────────────────────

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns = assign(assigns, :entries, IgnoreList.sorted_entries(assigns.session.ignore_list))

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.ignore_list_panel
        id={@id}
        target={@myself}
        entries={@entries}
        selected={@selected}
        show_add_dialog={@show_add_dialog}
        on_select="control_select"
        on_add="control_add_dialog"
        on_remove="control_remove"
      />
    </div>
    """
  end

  # ── Bubble helpers ───────────────────────────────────────────────

  defp put_session(socket, session) do
    send(self(), {:ab_session, session, :ignore})
    assign(socket, session: session)
  end

  defp bubble_status(socket, level, message) do
    send(self(), {:ab_status, level, message})
    socket
  end

  defp ignore_type_label(:all), do: dgettext("chat", "all")
  defp ignore_type_label(:messages), do: dgettext("chat", "messages")
  defp ignore_type_label(:notices), do: dgettext("chat", "notices")
  defp ignore_type_label(:invites), do: dgettext("chat", "invites")
  defp ignore_type_label(type), do: to_string(type)
end
