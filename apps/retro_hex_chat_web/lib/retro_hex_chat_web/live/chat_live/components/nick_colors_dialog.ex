defmodule RetroHexChatWeb.ChatLive.Components.NickColorsDialog do
  @moduledoc """
  Stateful island for the Nick Colors window — the per-nickname color overrides,
  with the palette editor and the add/edit sub-form modals.

  Mounted inside a server-managed desktop window: closing unmounts the island,
  resetting the selection, the palette index and any open sub-form. The
  `NickColors` mutations run here and produce a new `session`; the parent owns
  `session`, so the work bubbles up as `{:ab_session, session, :nick_colors}` —
  the parent assigns it, persists it, rebuilds `nick_color_fn` and refreshes the
  active message stream.

  The add sub-form uses `phx-update="ignore"` on its nickname input because the
  in-form color picker re-renders this component on every swatch click, which
  would otherwise wipe what was typed (same as the highlight dialog).
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.NickColorsDialog

  alias RetroHexChat.Accounts.{NickColors, Session}

  alias RetroHexChatWeb.ChatLive.Components.DialogIsland

  @id "nick-colors-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @initial %{
    selected: nil,
    palette_editing_index: nil,
    show_add_dialog: false,
    show_edit_dialog: false
  }

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket), do: DialogIsland.mount(socket, @id, @initial)

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket), do: DialogIsland.update(socket, assigns)

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("nick_color_select", %{"nickname" => nick}, socket) do
    {:noreply, assign(socket, selected: nick)}
  end

  def handle_event("nick_palette_pick", %{"index" => idx_str}, socket) do
    {:noreply, assign(socket, palette_editing_index: String.to_integer(idx_str))}
  end

  def handle_event("nick_color_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_add_dialog: true, palette_editing_index: nil)}
  end

  def handle_event("nick_color_add_cancel", _params, socket) do
    {:noreply, assign(socket, show_add_dialog: false)}
  end

  def handle_event(
        "nick_color_add",
        %{"nickname" => nickname, "color_index" => color_str},
        socket
      ) do
    session = socket.assigns.session
    nickname = String.trim(nickname)

    case NickColors.add_entry(session.nick_colors, nickname, String.to_integer(color_str)) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(show_add_dialog: false)
         |> put_session(Session.set_nick_colors(session, updated))}

      {:error, reason} ->
        {:noreply, bubble_status(socket, :error, nick_color_add_error(reason, nickname))}
    end
  end

  def handle_event("nick_color_edit_dialog", _params, socket) do
    color =
      NickColors.color_index_for(socket.assigns.session.nick_colors, socket.assigns.selected)

    {:noreply, assign(socket, show_edit_dialog: true, palette_editing_index: color)}
  end

  def handle_event("nick_color_edit_cancel", _params, socket) do
    {:noreply, assign(socket, show_edit_dialog: false)}
  end

  def handle_event("nick_color_edit", %{"color_index" => color_str} = params, socket) do
    session = socket.assigns.session
    nickname = params["nickname"] || socket.assigns.selected

    case NickColors.update_color(session.nick_colors, nickname, String.to_integer(color_str)) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(show_edit_dialog: false)
         |> put_session(Session.set_nick_colors(session, updated))}

      {:error, :not_found} ->
        {:noreply, bubble_status(socket, :error, dgettext("chat", "Nick color entry not found"))}

      {:error, :invalid_color} ->
        {:noreply, bubble_status(socket, :error, dgettext("chat", "Invalid color"))}
    end
  end

  def handle_event("nick_color_remove", params, socket) do
    session = socket.assigns.session
    nick = params["nickname"] || socket.assigns.selected

    case NickColors.remove_entry(session.nick_colors, nick) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(selected: nil)
         |> put_session(Session.set_nick_colors(session, updated))
         |> bubble_status(
           :system,
           dgettext("chat", "Removed custom color for %{nickname}", nickname: nick)
         )}

      {:error, :not_found} ->
        {:noreply,
         bubble_status(
           socket,
           :system,
           dgettext("chat", "%{nickname} has no custom color", nickname: nick)
         )}
    end
  end

  # ── Render ───────────────────────────────────────────────────────

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns =
      assign(assigns, :entries, NickColors.sorted_entries(assigns.session.nick_colors))

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.nick_colors_panel
        id={@id}
        target={@myself}
        nick_colors={@entries}
        selected={@selected}
        palette_editing_index={@palette_editing_index}
        show_add_dialog={@show_add_dialog}
        show_edit_dialog={@show_edit_dialog}
        on_select="nick_color_select"
        on_add="nick_color_add_dialog"
        on_edit="nick_color_edit_dialog"
        on_remove="nick_color_remove"
      />
    </div>
    """
  end

  # ── Bubble helpers ───────────────────────────────────────────────

  defp put_session(socket, session) do
    send(self(), {:ab_session, session, :nick_colors})
    assign(socket, session: session)
  end

  defp bubble_status(socket, level, message) do
    send(self(), {:ab_status, level, message})
    socket
  end

  defp nick_color_add_error(:duplicate, nick),
    do: dgettext("chat", "%{nickname} already has a custom color", nickname: nick)

  defp nick_color_add_error(:list_full, _nick),
    do: dgettext("chat", "Nick color list is full (max 50)")

  defp nick_color_add_error(:invalid_nickname, _nick), do: dgettext("chat", "Invalid nickname")
  defp nick_color_add_error(:invalid_color, _nick), do: dgettext("chat", "Invalid color")
end
