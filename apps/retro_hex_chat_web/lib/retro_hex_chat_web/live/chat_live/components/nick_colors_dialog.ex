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
  alias RetroHexChatWeb.ChatLive.Helpers.NickFlags

  use RetroHexChatWeb.ChatLive.Components.DialogIsland,
    id: "nick-colors-dialog",
    initial: %{
      selected: nil,
      palette_editing_index: nil,
      show_add_dialog: false,
      show_edit_dialog: false,
      entry_locales: %{},
      entry_locales_cache: nil
    }

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    {:ok, socket} = DialogIsland.update(socket, assigns)
    {:ok, put_locales(socket)}
  end

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("nick_color_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_add_dialog: true, palette_editing_index: nil)}
  end

  def handle_event("nick_color_add_cancel", _params, socket) do
    {:noreply, assign(socket, show_add_dialog: false)}
  end

  def handle_event("nick_color_add", %{"nickname" => nickname} = params, socket) do
    session = socket.assigns.session
    nickname = String.trim(nickname)

    with {:ok, color} <- color_index(params["color_index"]),
         {:ok, updated} <- NickColors.add_entry(session.nick_colors, nickname, color) do
      {:noreply,
       socket
       |> assign(show_add_dialog: false)
       |> put_session(Session.set_nick_colors(session, updated))}
    else
      :error ->
        {:noreply,
         DialogIsland.bubble(socket, :error, nick_color_add_error(:invalid_color, nickname))}

      {:error, reason} ->
        {:noreply, DialogIsland.bubble(socket, :error, nick_color_add_error(reason, nickname))}
    end
  end

  # The row's Edit names the nickname and opens the palette on its colour.
  def handle_event("nick_color_edit_dialog", %{"nickname" => nick}, socket) do
    color = NickColors.color_index_for(socket.assigns.session.nick_colors, nick)

    {:noreply,
     assign(socket, selected: nick, show_edit_dialog: true, palette_editing_index: color)}
  end

  def handle_event("nick_color_edit_cancel", _params, socket) do
    {:noreply, assign(socket, show_edit_dialog: false)}
  end

  def handle_event("nick_color_edit", params, socket) do
    session = socket.assigns.session
    nickname = params["nickname"] || socket.assigns.selected

    with {:ok, color} <- color_index(params["color_index"]),
         {:ok, updated} <- NickColors.update_color(session.nick_colors, nickname, color) do
      {:noreply,
       socket
       |> assign(show_edit_dialog: false)
       |> put_session(Session.set_nick_colors(session, updated))}
    else
      {:error, :not_found} ->
        {:noreply,
         DialogIsland.bubble(socket, :error, dgettext("chat", "Nick color entry not found"))}

      _invalid_color ->
        {:noreply, DialogIsland.bubble(socket, :error, dgettext("chat", "Invalid color"))}
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
         |> DialogIsland.bubble(
           :system,
           dgettext("chat", "Removed custom color for %{nickname}", nickname: nick)
         )}

      {:error, :not_found} ->
        {:noreply,
         DialogIsland.bubble(
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
        locales={@entry_locales}
        selected={@selected}
        palette_editing_index={@palette_editing_index}
        show_add_dialog={@show_add_dialog}
        show_edit_dialog={@show_edit_dialog}
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
    socket |> assign(session: session) |> put_locales()
  end

  # The flag beside each coloured nickname, asked for again only when the list
  # names different people — not on every re-render the parent sends down.
  defp put_locales(%{assigns: %{session: nil}} = socket), do: socket

  defp put_locales(socket) do
    nicks =
      Enum.map(
        NickColors.sorted_entries(socket.assigns.session.nick_colors),
        & &1.target_nickname
      )

    NickFlags.assign_locales(socket, nicks, :entry_locales, :entry_locales_cache)
  end

  # The swatches are a radio group, so a form submitted before anything was
  # picked carries no colour at all — not an empty one. `NickColors` has always
  # had an answer for a colour it will not accept; what was missing was getting
  # there, because parsing raised first, and a raise inside `handle_event` does
  # not fail the dialog: it takes the whole chat session down.
  defp color_index(value) do
    case Integer.parse(to_string(value)) do
      {index, ""} -> {:ok, index}
      _unparsable -> :error
    end
  end

  defp nick_color_add_error(:duplicate, nick),
    do: dgettext("chat", "%{nickname} already has a custom color", nickname: nick)

  defp nick_color_add_error(:list_full, _nick),
    do: dgettext("chat", "Nick color list is full (max 50)")

  defp nick_color_add_error(:invalid_nickname, _nick), do: dgettext("chat", "Invalid nickname")
  defp nick_color_add_error(:invalid_color, _nick), do: dgettext("chat", "Invalid color")
end
