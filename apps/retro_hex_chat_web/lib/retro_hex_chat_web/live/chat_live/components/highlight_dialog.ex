defmodule RetroHexChatWeb.ChatLive.Components.HighlightDialog do
  @moduledoc """
  Stateful island for the Highlight Words window body — the word list with
  per-word background color, plus the Add/Edit sub-form modals (centered over
  the enclosing desktop window) and their color pickers. Mounted inside a
  server-managed window: presence in the DOM means open, so closing unmounts
  the island and reopening starts from a clean selection.

  Owns the selected word, the color-picker draft, both sub-form `show_*` flags,
  every event (`@myself`), and the `HighlightWords` business logic.

  The modal-in-modal color-pick clobber (plan 41): the Add sub-form's word
  `<input>` is uncontrolled; when the color picker inside it submitted to the
  PARENT (cid mismatch), the background re-render reset the typed word. Fixed
  at the root (§0a-anti): a `target` attr threaded through the design-system
  `highlight_panel/1` — and through the `color_picker` primitive — puts
  `phx-target={@myself}` on the form, the close buttons AND the color swatches,
  so every event routes to the component that owns the DOM. The cid matches, so
  LiveView preserves the input across the color-pick re-render.

  Highlight words live on the `session` — the central read-model the message
  pipeline reads at render time to highlight inbound lines — so it stays
  parent-owned (§1d). The island runs the `HighlightWords` mutation and bubbles
  the new session via `send(self(), {:highlight_dialog_session, session})`; the
  parent assigns it + fires the fire-and-forget persist. Validation errors go to
  the status bar (a parent-owned surface) via
  `send(self(), {:highlight_status_error, msg})`.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.HighlightDialog

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.HighlightWords

  @id "highlight-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       highlight_selected: nil,
       highlight_selected_color: nil,
       show_highlight_add_dialog: false,
       show_highlight_edit_dialog: false,
       session: nil
     )}
  end

  # passthrough context (session)
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  # ── Selection ────────────────────────────────────────────────────

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("highlight_select", %{"word" => word}, socket) do
    {:noreply, assign(socket, highlight_selected: word)}
  end

  # ── Sub-form open/close ──────────────────────────────────────────

  def handle_event("open_highlight_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_highlight_add_dialog: true, highlight_selected_color: nil)}
  end

  def handle_event("close_highlight_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_highlight_add_dialog: false)}
  end

  def handle_event("open_highlight_edit_dialog", _params, socket) do
    {:noreply,
     assign(socket,
       show_highlight_edit_dialog: true,
       highlight_selected_color: selected_word_color(socket)
     )}
  end

  def handle_event("close_highlight_edit_dialog", _params, socket) do
    {:noreply, assign(socket, show_highlight_edit_dialog: false)}
  end

  def handle_event("highlight_dialog_close", _params, socket) do
    send(self(), {:close_window, "highlight"})
    {:noreply, socket}
  end

  def handle_event("highlight_color_pick", params, socket) do
    color = params["color"] || params["index"]
    {:noreply, assign(socket, highlight_selected_color: parse_optional_color(color))}
  end

  # ── Mutations ────────────────────────────────────────────────────

  def handle_event("highlight_add", %{"word" => word} = params, socket) do
    session = socket.assigns.session
    bg_color = parse_optional_color(params["bg_color"])

    case HighlightWords.add_entry(session.highlight_words, word, bg_color) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(show_highlight_add_dialog: false)
         |> put_session(Session.set_highlight_words(session, updated))}

      {:error, reason} ->
        {:noreply,
         bubble_status_error(
           socket,
           dgettext("chat", "Cannot add highlight: %{reason}", reason: reason)
         )}
    end
  end

  def handle_event("highlight_remove", %{"word" => word}, socket) do
    session = socket.assigns.session

    case HighlightWords.remove_entry(session.highlight_words, word) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(highlight_selected: nil)
         |> put_session(Session.set_highlight_words(session, updated))}

      {:error, :not_found} ->
        {:noreply, bubble_status_error(socket, dgettext("chat", "Word not in highlight list"))}
    end
  end

  def handle_event("highlight_edit", %{"word" => word} = params, socket) do
    session = socket.assigns.session
    bg_color = parse_optional_color(params["bg_color"])

    case HighlightWords.update_entry(session.highlight_words, word, bg_color) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(show_highlight_edit_dialog: false)
         |> put_session(Session.set_highlight_words(session, updated))}

      {:error, reason} ->
        {:noreply,
         bubble_status_error(
           socket,
           dgettext("chat", "Cannot update highlight: %{reason}", reason: reason)
         )}
    end
  end

  # ── Render ───────────────────────────────────────────────────────

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns = assign(assigns, words: HighlightWords.entries(assigns.session.highlight_words))

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.highlight_panel
        id={@id}
        target={@myself}
        words={@words}
        own_nick={@session.nickname}
        selected_word={@highlight_selected}
        selected_color={@highlight_selected_color}
        show_highlight_add_dialog={@show_highlight_add_dialog}
        show_highlight_edit_dialog={@show_highlight_edit_dialog}
        on_select="highlight_select"
        on_add="open_highlight_add_dialog"
        on_edit="open_highlight_edit_dialog"
        on_remove="highlight_remove"
        on_color_select="highlight_color_pick"
        on_close="highlight_dialog_close"
      />
    </div>
    """
  end

  # ── Internal helpers ─────────────────────────────────────────────

  defp selected_word_color(socket) do
    case socket.assigns.highlight_selected do
      nil ->
        nil

      word ->
        socket.assigns.session.highlight_words
        |> HighlightWords.entries()
        |> Enum.find(fn e -> e.word == word end)
        |> case do
          nil -> nil
          entry -> entry.bg_color
        end
    end
  end

  # Optimistically reflect the new session locally (the word list refreshes this
  # cycle) while the parent assigns it as the canonical read-model and persists it.
  defp put_session(socket, session) do
    send(self(), {:highlight_dialog_session, session})
    assign(socket, session: session)
  end

  defp bubble_status_error(socket, message) do
    send(self(), {:highlight_status_error, message})
    socket
  end

  @spec parse_optional_color(String.t() | nil) :: non_neg_integer() | nil
  defp parse_optional_color(nil), do: nil
  defp parse_optional_color(""), do: nil

  defp parse_optional_color(str) when is_binary(str) do
    case Integer.parse(str) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp parse_optional_color(n) when is_integer(n), do: n
end
