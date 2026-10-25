defmodule RetroHexChatWeb.ChatLive.Components.IgnoreListDialog do
  @moduledoc """
  Stateful island for the Ignore List window — the ignored nicknames with their
  scope and expiry, plus the add sub-form modal.

  Mounted inside a server-managed desktop window: closing unmounts the island,
  resetting the selection and any open sub-form. The `IgnoreList` mutations run
  here and produce a new `session`; the parent owns `session` and the expiry
  timers, so the work bubbles up:

    * `{:dialog_session, session, :ignore}` — parent assigns + persists.
    * `DialogIsland.bubble/3` — chat-surface status / error lines.
    * `{:ab_ignore_timer, op, ...}` — the parent owns the ignore debounce timers.
  """

  alias RetroHexChat.Nickname
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.IgnoreListDialog
  import RetroHexChatWeb.ChatLive.Helpers, only: [parse_dialog_duration: 1]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.IgnoreList

  alias RetroHexChatWeb.ChatLive.Components.DialogIsland
  alias RetroHexChatWeb.ChatLive.Helpers.NickFlags

  use RetroHexChatWeb.ChatLive.Components.DialogIsland,
    id: "ignore-list-dialog",
    initial: %{show_add_dialog: false, entry_locales: %{}, entry_locales_cache: nil}

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    {:ok, socket} = DialogIsland.update(socket, assigns)
    {:ok, put_locales(socket)}
  end

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
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
      Nickname.equal?(String.trim(nick), session.nickname) ->
        {:noreply,
         DialogIsland.bubble(socket, :error_event, dgettext("chat", "You cannot ignore yourself"))}

      duration_str not in [nil, ""] and match?({nil, nil}, parse_dialog_duration(duration_str)) ->
        {:noreply,
         DialogIsland.bubble(
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
             |> DialogIsland.bubble(
               :system_event,
               dgettext("chat", "* %{nickname} is now ignored (%{type})",
                 nickname: nick,
                 type: ignore_type_label(type)
               )
             )}

          {:error, reason} ->
            {:noreply,
             DialogIsland.bubble(
               socket,
               :error_event,
               dgettext("chat", "Failed to add ignore: %{reason}", reason: reason)
             )}
        end
    end
  end

  def handle_event("control_remove", %{"nickname" => nick}, socket) do
    session = socket.assigns.session

    with true <- nick != nil,
         {:ok, updated_list} <- IgnoreList.remove_entry(session.ignore_list, nick) do
      send(self(), {:ab_ignore_timer, :remove, nick})

      {:noreply,
       socket
       |> put_session(Session.set_ignore_list(session, updated_list))
       |> DialogIsland.bubble(
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
        locales={@entry_locales}
        show_add_dialog={@show_add_dialog}
        on_add="control_add_dialog"
        on_remove="control_remove"
      />
    </div>
    """
  end

  # ── Bubble helpers ───────────────────────────────────────────────

  defp put_session(socket, session) do
    send(self(), {:dialog_session, session, :ignore})
    socket |> assign(session: session) |> put_locales()
  end

  # The flag beside each ignored nickname, asked for again only when the list
  # names different people — not on every re-render the parent sends down.
  defp put_locales(%{assigns: %{session: nil}} = socket), do: socket

  defp put_locales(socket) do
    nicks = Enum.map(IgnoreList.sorted_entries(socket.assigns.session.ignore_list), & &1.nickname)
    NickFlags.assign_locales(socket, nicks, :entry_locales, :entry_locales_cache)
  end

  defp ignore_type_label(:all), do: dgettext("chat", "all")
  defp ignore_type_label(:messages), do: dgettext("chat", "messages")
  defp ignore_type_label(:notices), do: dgettext("chat", "notices")
  defp ignore_type_label(:invites), do: dgettext("chat", "invites")
  defp ignore_type_label(type), do: to_string(type)
end
