defmodule RetroHexChatWeb.ChatLive.HighlightEvents do
  @moduledoc """
  Handle events for the Highlight Words dialog.

  Covers: open/close_highlight_dialog, highlight_select, open/close_highlight_add_dialog,
  open/close_highlight_edit_dialog, highlight_color_pick, highlight_add, highlight_remove,
  highlight_edit.

  Attached as `attach_hook(:highlight_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [maybe_persist_highlight_words: 2, push_status_message: 3]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.HighlightWords

  def handle_event("open_highlight_dialog", _params, socket) do
    {:halt, assign(socket, show_highlight_dialog: true)}
  end

  def handle_event("close_highlight_dialog", _params, socket) do
    {:halt,
     assign(socket,
       show_highlight_dialog: false,
       show_highlight_add_dialog: false,
       show_highlight_edit_dialog: false,
       highlight_selected: nil
     )}
  end

  def handle_event("highlight_select", %{"word" => word}, socket) do
    {:halt, assign(socket, highlight_selected: word)}
  end

  def handle_event("open_highlight_add_dialog", _params, socket) do
    {:halt, assign(socket, show_highlight_add_dialog: true, highlight_selected_color: nil)}
  end

  def handle_event("close_highlight_add_dialog", _params, socket) do
    {:halt, assign(socket, show_highlight_add_dialog: false)}
  end

  def handle_event("open_highlight_edit_dialog", _params, socket) do
    current_color =
      case socket.assigns.highlight_selected do
        nil ->
          nil

        word ->
          session = socket.assigns.session

          session.highlight_words
          |> HighlightWords.entries()
          |> Enum.find(fn e -> e.word == word end)
          |> case do
            nil -> nil
            entry -> entry.bg_color
          end
      end

    {:halt,
     assign(socket, show_highlight_edit_dialog: true, highlight_selected_color: current_color)}
  end

  def handle_event("close_highlight_edit_dialog", _params, socket) do
    {:halt, assign(socket, show_highlight_edit_dialog: false)}
  end

  def handle_event("highlight_color_pick", params, socket) do
    color = params["color"] || params["index"]
    {:halt, assign(socket, highlight_selected_color: parse_optional_color(color))}
  end

  def handle_event("highlight_add", %{"word" => word} = params, socket) do
    session = socket.assigns.session
    bg_color = parse_optional_color(params["bg_color"])

    case HighlightWords.add_entry(session.highlight_words, word, bg_color) do
      {:ok, updated} ->
        new_session = Session.set_highlight_words(session, updated)

        {:halt,
         socket
         |> assign(session: new_session, show_highlight_add_dialog: false)
         |> maybe_persist_highlight_words(new_session)}

      {:error, reason} ->
        {:halt,
         push_status_message(
           socket,
           dgettext("chat", "Cannot add highlight: %{reason}", reason: reason),
           :error
         )}
    end
  end

  def handle_event("highlight_remove", %{"word" => word}, socket) do
    session = socket.assigns.session

    case HighlightWords.remove_entry(session.highlight_words, word) do
      {:ok, updated} ->
        new_session = Session.set_highlight_words(session, updated)

        {:halt,
         socket
         |> assign(session: new_session, highlight_selected: nil)
         |> maybe_persist_highlight_words(new_session)}

      {:error, :not_found} ->
        {:halt,
         push_status_message(socket, dgettext("chat", "Word not in highlight list"), :error)}
    end
  end

  def handle_event("highlight_edit", %{"word" => word} = params, socket) do
    session = socket.assigns.session
    bg_color = parse_optional_color(params["bg_color"])

    case HighlightWords.update_entry(session.highlight_words, word, bg_color) do
      {:ok, updated} ->
        new_session = Session.set_highlight_words(session, updated)

        {:halt,
         socket
         |> assign(session: new_session, show_highlight_edit_dialog: false)
         |> maybe_persist_highlight_words(new_session)}

      {:error, reason} ->
        {:halt,
         push_status_message(
           socket,
           dgettext("chat", "Cannot update highlight: %{reason}", reason: reason),
           :error
         )}
    end
  end

  # ── Catch-all ──────────────────────────────────────────────

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── Private ────────────────────────────────────────────────

  @spec parse_optional_color(String.t() | nil) :: non_neg_integer() | nil
  defp parse_optional_color(nil), do: nil
  defp parse_optional_color(""), do: nil

  defp parse_optional_color(str) when is_binary(str) do
    case Integer.parse(str) do
      {n, ""} -> n
      _ -> nil
    end
  end
end
