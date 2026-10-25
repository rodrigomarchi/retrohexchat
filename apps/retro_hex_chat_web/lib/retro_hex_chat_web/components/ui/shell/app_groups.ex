defmodule RetroHexChatWeb.Components.UI.AppGroups do
  @moduledoc """
  The chat's own windows and account actions, grouped by what they are for.

  The Start menu's submenus and the desktop's folders list the same groups, in
  the same order, from this one list. Each item is one of:

    * `%{kind: :window, window: id, ...}` — opened client-side through
      `data-window-open`, no server round trip;
    * `%{kind: :action, action: event, ...}` — sent to the server, which
      runs whatever opening it involves (rows read from the database,
      channel state, identity sync) or acts without a window;
    * `%{kind: :separator}`.

  Labels are resolved on every call, never in a module attribute, so they
  follow the reader's locale.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  @type item ::
          %{kind: :window, window: String.t(), label: String.t(), icon_fn: atom()}
          | %{kind: :action, action: String.t(), label: String.t(), icon_fn: atom()}
          | %{kind: :separator}

  @type group :: :tools | :automation | :account

  @doc "The items of one group, in display order."
  @spec items(group()) :: [item()]
  def items(:tools) do
    [
      window("address-book", dgettext("ui", "Address Book"), :icon_btn_address_book),
      window("notify-list", dgettext("ui", "Notify List"), :icon_tab_notify),
      window("ignore-list", dgettext("ui", "Ignore List"), :icon_btn_ignore_list),
      window("highlight", dgettext("ui", "Highlight Words"), :icon_btn_highlight_words),
      window("user-lookup", dgettext("ui", "User Lookup"), :icon_btn_search),
      window("url-catcher", dgettext("ui", "URL Catcher"), :icon_btn_url_catcher),
      # Saved messages and events are read from the database on open.
      action("open_saved_dialog", dgettext("ui", "Saved Messages"), :icon_btn_star),
      action("open_events_dialog", dgettext("ui", "Events"), :icon_clock),
      # /list rows and channel state are loaded by the LiveView on open.
      action("toggle_channel_list", dgettext("ui", "Channel List"), :icon_btn_channel_list),
      action(
        "open_channel_central",
        dgettext("ui", "Channel Central"),
        :icon_btn_channel_central
      ),
      separator(),
      window("nick-colors", dgettext("ui", "Nick Colors"), :icon_btn_nick_colors),
      window("sound-settings", dgettext("ui", "Sounds"), :icon_btn_sounds),
      window("flood-protection", dgettext("ui", "Flood Protection"), :icon_btn_flood_protection)
    ]
  end

  def items(:automation) do
    [
      window("perform", dgettext("ui", "Perform"), :icon_btn_perform),
      window("autojoin", dgettext("ui", "Auto-Join"), :icon_btn_autojoin),
      window("auto-respond", dgettext("ui", "Auto Respond"), :icon_btn_auto_respond),
      window("alias", dgettext("ui", "Alias Editor"), :icon_btn_alias_editor),
      window("custom-menus", dgettext("ui", "Custom Menus"), :icon_btn_custom_menus),
      window("timers", dgettext("ui", "Timers"), :icon_btn_timers)
    ]
  end

  # Account entries go to the server: most open a window after syncing identity
  # or seeding the bio, and Account Info prints into the status window.
  def items(:account) do
    [
      # Claiming a nick and proving it come before everything else here.
      action("open_account_register", dgettext("ui", "Register Nickname..."), :icon_lock),
      action("open_account_identify", dgettext("ui", "Identify..."), :icon_status_user),
      separator(),
      action("open_account_dialog", dgettext("ui", "Account"), :icon_status_user),
      action("open_profile_dialog", dgettext("ui", "Profile"), :icon_btn_profile),
      action("open_away_dialog", dgettext("ui", "Away"), :icon_btn_away),
      action("open_user_modes_dialog", dgettext("ui", "User Modes"), :icon_btn_user_modes),
      action("open_trusted_terminals_dialog", dgettext("ui", "Trusted Terminals"), :icon_lock),
      separator(),
      # Prints what the server knows about you into the status window rather
      # than opening one of its own.
      action("account_info", dgettext("ui", "Account Info"), :icon_tab_status)
    ]
  end

  defp window(id, label, icon_fn),
    do: %{kind: :window, window: id, label: label, icon_fn: icon_fn}

  defp action(event, label, icon_fn),
    do: %{kind: :action, action: event, label: label, icon_fn: icon_fn}

  defp separator, do: %{kind: :separator}
end
