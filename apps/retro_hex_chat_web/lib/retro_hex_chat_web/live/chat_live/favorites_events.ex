defmodule RetroHexChatWeb.ChatLive.FavoritesEvents do
  @moduledoc """
  Handle events for channel favorites management.

  Covers: channel_right_click, close_treebar_context_menu,
  add_to_favorites, save_favorite, close_favorite_dialog,
  join_favorite, open_organize_favorites, close_organize_favorites,
  favorite_select, favorite_move_up, favorite_move_down,
  favorite_edit, favorite_remove.

  Attached as an `attach_hook(:favorites_events, :handle_event, ...)` in ChatLive.mount/3.
  Returns `{:halt, socket}` when the event is handled, `{:cont, socket}` otherwise.
  """

  import Phoenix.Component, only: [assign: 2]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [maybe_persist_favorites: 2, join_channel: 4]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.Favorites

  # ── Context menu ─────────────────────────────────────────

  def handle_event("channel_right_click", %{"channel" => channel} = params, socket) do
    x = params["x"] || 0
    y = params["y"] || 0

    {:halt,
     assign(socket,
       treebar_context_menu: %{visible: true, x: x, y: y, channel: channel}
     )}
  end

  def handle_event("close_treebar_context_menu", _params, socket) do
    {:halt, assign(socket, treebar_context_menu: %{visible: false, x: 0, y: 0, channel: nil})}
  end

  # ── Add / Save / Close favorite dialog ───────────────────

  def handle_event("add_to_favorites", %{"channel" => channel}, socket) do
    session = socket.assigns.session
    favorites = Session.get_favorites(session)

    if Favorites.has_entry?(favorites, channel) do
      existing = Favorites.find_entry(favorites, channel)

      {:halt,
       assign(socket,
         treebar_context_menu: %{visible: false, x: 0, y: 0, channel: nil},
         show_favorite_dialog: true,
         favorite_dialog_mode: :edit,
         favorite_dialog_channel: channel,
         favorite_dialog_is_duplicate: true,
         favorite_dialog_data: %{
           description: existing.description,
           auto_join: existing.auto_join,
           has_password: existing.password != nil and existing.password != ""
         }
       )}
    else
      {:halt,
       assign(socket,
         treebar_context_menu: %{visible: false, x: 0, y: 0, channel: nil},
         show_favorite_dialog: true,
         favorite_dialog_mode: :add,
         favorite_dialog_channel: channel,
         favorite_dialog_is_duplicate: false,
         favorite_dialog_data: nil
       )}
    end
  end

  def handle_event("save_favorite", params, socket) do
    session = socket.assigns.session
    favorites = Session.get_favorites(session)
    channel = params["channel_name"]
    password = if params["password"] != "", do: params["password"]
    auto_join = params["auto_join"] == "true"

    attrs = %{
      channel_name: channel,
      description: params["description"] || "",
      password: password,
      auto_join: auto_join
    }

    updated_favorites =
      if Favorites.has_entry?(favorites, channel) do
        case Favorites.update_entry(favorites, channel, attrs) do
          {:ok, updated} -> updated
          {:error, _} -> favorites
        end
      else
        case Favorites.add_entry(favorites, attrs) do
          {:ok, updated} -> updated
          {:error, _} -> favorites
        end
      end

    new_session = Session.set_favorites(session, updated_favorites)
    maybe_persist_favorites(socket, new_session)

    {:halt,
     assign(socket,
       session: new_session,
       show_favorite_dialog: false,
       favorite_dialog_channel: nil,
       favorite_dialog_data: nil,
       favorite_dialog_is_duplicate: false
     )}
  end

  def handle_event("close_favorite_dialog", _params, socket) do
    {:halt,
     assign(socket,
       show_favorite_dialog: false,
       favorite_dialog_channel: nil,
       favorite_dialog_data: nil,
       favorite_dialog_is_duplicate: false
     )}
  end

  # ── Join favorite ────────────────────────────────────────

  def handle_event("join_favorite", %{"channel" => channel}, socket) do
    session = socket.assigns.session
    favorites = Session.get_favorites(session)

    if channel in session.channels do
      # Already joined — just switch
      new_session = Session.set_active_channel(session, channel)
      {:halt, assign(socket, session: new_session)}
    else
      # Join using saved password if available
      entry = Favorites.find_entry(favorites, channel)
      password = if entry, do: entry.password

      {:halt, join_channel(socket, channel, session, password)}
    end
  end

  # ── Organize favorites ───────────────────────────────────

  def handle_event("open_organize_favorites", _params, socket) do
    {:halt, assign(socket, show_organize_favorites: true, organize_favorites_selected: nil)}
  end

  def handle_event("close_organize_favorites", _params, socket) do
    {:halt, assign(socket, show_organize_favorites: false, organize_favorites_selected: nil)}
  end

  def handle_event("favorite_select", %{"channel" => channel}, socket) do
    {:halt, assign(socket, organize_favorites_selected: channel)}
  end

  def handle_event("favorite_move_up", _params, socket) do
    selected = socket.assigns.organize_favorites_selected

    if selected do
      session = socket.assigns.session
      favorites = Session.get_favorites(session)
      updated = Favorites.move_up(favorites, selected)
      new_session = Session.set_favorites(session, updated)
      maybe_persist_favorites(socket, new_session)
      {:halt, assign(socket, session: new_session)}
    else
      {:halt, socket}
    end
  end

  def handle_event("favorite_move_down", _params, socket) do
    selected = socket.assigns.organize_favorites_selected

    if selected do
      session = socket.assigns.session
      favorites = Session.get_favorites(session)
      updated = Favorites.move_down(favorites, selected)
      new_session = Session.set_favorites(session, updated)
      maybe_persist_favorites(socket, new_session)
      {:halt, assign(socket, session: new_session)}
    else
      {:halt, socket}
    end
  end

  def handle_event("favorite_edit", _params, socket) do
    selected = socket.assigns.organize_favorites_selected

    if selected do
      session = socket.assigns.session
      favorites = Session.get_favorites(session)
      entry = Favorites.find_entry(favorites, selected)

      if entry do
        {:halt,
         assign(socket,
           show_favorite_dialog: true,
           favorite_dialog_mode: :edit,
           favorite_dialog_channel: entry.channel_name,
           favorite_dialog_is_duplicate: false,
           favorite_dialog_data: %{
             description: entry.description,
             auto_join: entry.auto_join,
             has_password: entry.password != nil and entry.password != ""
           }
         )}
      else
        {:halt, socket}
      end
    else
      {:halt, socket}
    end
  end

  def handle_event("favorite_remove", _params, socket) do
    selected = socket.assigns.organize_favorites_selected

    if selected do
      session = socket.assigns.session
      favorites = Session.get_favorites(session)

      case Favorites.remove_entry(favorites, selected) do
        {:ok, updated} ->
          new_session = Session.set_favorites(session, updated)
          maybe_persist_favorites(socket, new_session)
          {:halt, assign(socket, session: new_session, organize_favorites_selected: nil)}

        {:error, _} ->
          {:halt, socket}
      end
    else
      {:halt, socket}
    end
  end

  # ── Catch-all: pass unhandled events to next hook ────────

  def handle_event(_event, _params, socket), do: {:cont, socket}
end
