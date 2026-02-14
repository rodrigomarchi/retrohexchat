defmodule RetroHexChatWeb.ChatLive.OptionsEvents do
  @moduledoc """
  Handle Options dialog events.

  Covers: open/close, panel selection, display toggles, font/color/connect/
  messages/keybinding changes, OK/Apply/Cancel with draft state pattern.

  Attached as `attach_hook(:options_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, stream: 4]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.{KeyBindings, UserPreferences}
  alias RetroHexChatWeb.ChatLive.Helpers.Persistence

  # ---------------------------------------------------------------------------
  # Dialog Lifecycle
  # ---------------------------------------------------------------------------

  def handle_event("open_options_dialog", _params, socket) do
    if socket.assigns.show_options_dialog do
      # Already open — focus (no duplicate)
      {:halt, socket}
    else
      draft = socket.assigns.session.user_preferences
      {:halt, assign(socket, show_options_dialog: true, options_draft: draft)}
    end
  end

  def handle_event("close_options_dialog", _params, socket) do
    {:halt, assign(socket, show_options_dialog: false, options_draft: nil)}
  end

  def handle_event("options_select_panel", %{"panel" => panel}, socket) do
    {:halt, assign(socket, options_panel: panel)}
  end

  def handle_event("options_ok", _params, socket) do
    socket =
      socket
      |> apply_draft()
      |> assign(show_options_dialog: false, options_draft: nil)

    {:halt, socket}
  end

  def handle_event("options_apply", _params, socket) do
    {:halt, apply_draft(socket)}
  end

  # ---------------------------------------------------------------------------
  # Display Panel
  # ---------------------------------------------------------------------------

  def handle_event("options_toggle_display", %{"setting" => setting_str}, socket) do
    setting = String.to_existing_atom(setting_str)
    draft = socket.assigns.options_draft
    current = Map.get(draft.display, setting)
    updated_draft = UserPreferences.set_display(draft, setting, !current)
    {:halt, assign(socket, options_draft: updated_draft)}
  end

  def handle_event("options_change_quit_message", %{"value" => value}, socket) do
    draft = socket.assigns.options_draft
    message = if String.trim(value) == "", do: "Leaving", else: value
    updated_draft = UserPreferences.set_quit_message(draft, message)
    {:halt, assign(socket, options_draft: updated_draft)}
  end

  def handle_event("options_change_timestamp_format", %{"timestamp_format" => value}, socket) do
    draft = socket.assigns.options_draft
    format = String.to_existing_atom(value)
    updated_draft = UserPreferences.set_timestamp_format(draft, format)
    {:halt, assign(socket, options_draft: updated_draft)}
  end

  def handle_event("update_command_help_level", %{"level" => level_str}, socket) do
    level = String.to_existing_atom(level_str)

    if socket.assigns.options_draft do
      draft = socket.assigns.options_draft
      updated_draft = UserPreferences.set_command_help_level(draft, level)
      {:halt, assign(socket, options_draft: updated_draft, command_help_level: level)}
    else
      session = socket.assigns.session
      updated_prefs = UserPreferences.set_command_help_level(session.user_preferences, level)
      updated_session = %{session | user_preferences: updated_prefs}
      {:halt, assign(socket, session: updated_session, command_help_level: level)}
    end
  end

  # ---------------------------------------------------------------------------
  # Fonts Panel
  # ---------------------------------------------------------------------------

  def handle_event("options_change_font", params, socket) do
    draft = socket.assigns.options_draft
    updated_draft = apply_font_change(draft, params)
    {:halt, assign(socket, options_draft: updated_draft)}
  end

  # ---------------------------------------------------------------------------
  # Colors Panel
  # ---------------------------------------------------------------------------

  def handle_event("options_change_color", %{"slot" => slot_str, "color" => color}, socket) do
    slot = String.to_existing_atom(slot_str)
    draft = UserPreferences.set_color(socket.assigns.options_draft, slot, color)
    {:halt, assign(socket, options_draft: draft)}
  end

  def handle_event("options_select_nick_color", %{"index" => index_str}, socket) do
    # For now, cycle through palette or open a picker; simple implementation
    {:halt, assign(socket, nick_palette_editing_index: String.to_integer(index_str))}
  end

  def handle_event(
        "options_change_nick_color",
        %{"index" => index_str, "color" => color},
        socket
      ) do
    index = String.to_integer(index_str)
    draft = UserPreferences.set_nick_palette_color(socket.assigns.options_draft, index, color)
    {:halt, assign(socket, options_draft: draft)}
  end

  # ---------------------------------------------------------------------------
  # Connect Panel
  # ---------------------------------------------------------------------------

  def handle_event(
        "options_change_connect",
        %{"setting" => "auto_reconnect_enabled", "value" => value_str},
        socket
      ) do
    value = value_str == "true"

    draft =
      UserPreferences.set_connect(socket.assigns.options_draft, :auto_reconnect_enabled, value)

    {:halt, assign(socket, options_draft: draft)}
  end

  def handle_event("options_change_connect_number", params, socket) do
    draft = socket.assigns.options_draft

    updated_draft =
      Enum.reduce(~w(retry_interval max_retries connection_timeout), draft, fn key, acc ->
        case Map.get(params, key) do
          nil -> acc
          val_str -> try_set_connect(acc, String.to_existing_atom(key), val_str)
        end
      end)

    {:halt, assign(socket, options_draft: updated_draft)}
  end

  # ---------------------------------------------------------------------------
  # Messages Panel
  # ---------------------------------------------------------------------------

  def handle_event("options_change_routing", params, socket) do
    draft = socket.assigns.options_draft

    updated_draft =
      Enum.reduce(~w(whois_routing notice_routing pm_routing), draft, fn key, acc ->
        case Map.get(params, key) do
          nil ->
            acc

          val_str ->
            UserPreferences.set_routing(
              acc,
              String.to_existing_atom(key),
              String.to_existing_atom(val_str)
            )
        end
      end)

    {:halt, assign(socket, options_draft: updated_draft)}
  end

  # ---------------------------------------------------------------------------
  # Key Bindings Panel
  # ---------------------------------------------------------------------------

  def handle_event("options_select_binding", %{"action" => action_str}, socket) do
    action = String.to_existing_atom(action_str)
    socket = assign(socket, keybinding_editing: action)
    {:halt, push_event(socket, "start_key_capture", %{action: action_str})}
  end

  def handle_event("options_capture_key", params, socket) do
    action = String.to_existing_atom(params["action"])

    binding = %{
      key: params["key"],
      modifiers: build_modifiers(params)
    }

    cond do
      KeyBindings.reserved?(binding) ->
        {:halt,
         assign(socket, keybinding_warning: "This key combination is reserved by the browser.")}

      KeyBindings.conflict?(socket.assigns.options_draft.key_bindings, action, binding) ->
        {:halt,
         assign(socket,
           keybinding_warning: "This key combination is already assigned to another action."
         )}

      true ->
        draft = UserPreferences.set_key_binding(socket.assigns.options_draft, action, binding)

        {:halt,
         assign(socket,
           options_draft: draft,
           keybinding_editing: nil,
           keybinding_warning: nil
         )}
    end
  end

  def handle_event("options_clear_binding", %{"action" => action_str}, socket) do
    action = String.to_existing_atom(action_str)
    draft = UserPreferences.set_key_binding(socket.assigns.options_draft, action, nil)
    {:halt, assign(socket, options_draft: draft, keybinding_editing: nil)}
  end

  def handle_event("options_reset_bindings", _params, socket) do
    draft = UserPreferences.set_key_bindings(socket.assigns.options_draft, KeyBindings.defaults())

    {:halt,
     assign(socket, options_draft: draft, keybinding_editing: nil, keybinding_warning: nil)}
  end

  # ---------------------------------------------------------------------------
  # Catch-all
  # ---------------------------------------------------------------------------

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ---------------------------------------------------------------------------
  # Private: Apply draft to live state
  # ---------------------------------------------------------------------------

  defp apply_draft(socket) do
    draft = socket.assigns.options_draft
    session = socket.assigns.session

    # Update session with new preferences
    updated_session = Session.set_user_preferences(session, draft)

    # Sync notice_routing if changed
    updated_session =
      if draft.messages.notice_routing != session.notice_routing do
        Session.set_notice_routing(updated_session, draft.messages.notice_routing)
      else
        updated_session
      end

    # Apply display settings to live assigns
    new_format = Map.get(draft.display, :timestamp_format, :hh_mm)
    old_format = socket.assigns.timestamp_format

    socket
    |> assign(
      session: updated_session,
      options_draft: draft,
      show_toolbar: draft.display.show_toolbar,
      show_treebar: draft.display.show_treebar,
      show_switchbar: draft.display.show_switchbar,
      show_statusbar: draft.display.show_statusbar,
      compact_mode: draft.display.compact_mode,
      line_shading: draft.display.line_shading,
      show_contextual_tips: draft.display.show_contextual_tips,
      timestamp_format: new_format
    )
    |> maybe_reset_streams_for_timestamp(old_format, new_format)
    |> push_event("apply_preferences", %{styles: UserPreferences.to_css_styles(draft)})
    |> push_event("tips_toggle", %{enabled: draft.display.show_contextual_tips})
    |> push_event("reconnect_config", %{
      enabled: draft.connect.auto_reconnect_enabled,
      max_attempts: draft.connect.max_retries,
      max_delay: draft.connect.retry_interval
    })
    |> push_event("update_bindings", %{
      bindings: KeyBindings.to_persistable(draft.key_bindings)
    })
    |> Persistence.maybe_persist_user_preferences(updated_session)
  end

  defp maybe_reset_streams_for_timestamp(socket, same, same), do: socket

  defp maybe_reset_streams_for_timestamp(socket, _old, _new) do
    socket
    |> stream(:chat_messages, [], reset: true)
    |> stream(:status_messages, [], reset: true)
  end

  # ---------------------------------------------------------------------------
  # Private: Font change helpers
  # ---------------------------------------------------------------------------

  defp apply_font_change(draft, params) do
    Enum.reduce(~w(chat_messages input_box nicklist treebar), draft, fn area, acc ->
      family = Map.get(params, "font_family_#{area}")
      size_str = Map.get(params, "font_size_#{area}")
      area_atom = String.to_existing_atom(area)
      apply_font_area(acc, area_atom, family, size_str)
    end)
  end

  defp apply_font_area(draft, _area, nil, nil), do: draft

  defp apply_font_area(draft, area, family, nil) when is_binary(family) do
    current_size = get_in(draft, [:fonts, area, :size])
    UserPreferences.set_font(draft, area, %{family: family, size: current_size})
  end

  defp apply_font_area(draft, area, nil, size_str) when is_binary(size_str) do
    current_family = get_in(draft, [:fonts, area, :family])
    apply_font_with_size(draft, area, current_family, size_str)
  end

  defp apply_font_area(draft, area, family, size_str)
       when is_binary(family) and is_binary(size_str) do
    apply_font_with_size(draft, area, family, size_str)
  end

  defp apply_font_with_size(draft, area, family, size_str) do
    case Integer.parse(size_str) do
      {size, _} when size >= 8 and size <= 24 ->
        UserPreferences.set_font(draft, area, %{family: family, size: size})

      _ ->
        draft
    end
  end

  defp try_set_connect(draft, key, val_str) do
    case Integer.parse(val_str) do
      {val, _} -> UserPreferences.set_connect(draft, key, val)
      :error -> draft
    end
  rescue
    FunctionClauseError -> draft
  end

  defp build_modifiers(params) do
    []
    |> maybe_add_modifier(params["ctrlKey"], :ctrl)
    |> maybe_add_modifier(params["altKey"], :alt)
    |> maybe_add_modifier(params["shiftKey"], :shift)
  end

  defp maybe_add_modifier(mods, true, mod), do: [mod | mods]
  defp maybe_add_modifier(mods, _, _mod), do: mods
end
