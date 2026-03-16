# Script to convert help HTML files to HEEx templates with icons
# Usage: elixir scripts/convert_help_to_heex.exs [file1.html file2.html ...]
# If no files specified, converts all files in priv/help/

defmodule HelpConverter do
  @source_dir "apps/retro_hex_chat/priv/help"
  @target_dir "apps/retro_hex_chat_web/lib/retro_hex_chat_web/controllers/help_content"

  # h4 heading → icon atom mapping
  @heading_icons %{
    # High-frequency
    "See Also" => ":icon_link",
    "How It Works" => ":icon_tab_control",
    "Syntax" => ":icon_code",
    "Examples" => ":icon_lightbulb",
    "Parameters" => ":icon_tag",
    "Rules &amp; Limits" => ":icon_rules",
    "Usage" => ":icon_terminal",
    "Notes" => ":icon_document_alert",
    "Opening" => ":icon_folder",
    "Limits" => ":icon_rules",
    "Requirements" => ":icon_checkmark",
    "Persistence" => ":icon_btn_save",
    "Features" => ":icon_star",
    # Mid-frequency
    "Key Behaviors" => ":icon_tab_general",
    "Closing" => ":icon_close",
    "Trigger Rules" => ":icon_dialog_flood",
    "Tabs" => ":icon_tab_channel",
    "Subcommands" => ":icon_terminal",
    "Safety Features" => ":icon_shield",
    "Permissions" => ":icon_tab_modes",
    "Per-Channel Levels" => ":icon_role_operator",
    "Navigation" => ":icon_btn_next",
    "Limitations" => ":icon_warning",
    "Layout" => ":icon_tab_display",
    "Keyboard Navigation" => ":icon_dialog_cheatsheet",
    "Important Notes" => ":icon_warning",
    "Edge Cases" => ":icon_warning",
    "Commands" => ":icon_terminal",
    "Channel Modes" => ":icon_tab_modes",
    "Categories" => ":icon_folder",
    "Behavior" => ":icon_tab_general",
    # One-offs: Access/Security
    "Access Levels" => ":icon_shield",
    "ChanServ Auto-Grant" => ":icon_shield",
    "Rank Hierarchy" => ":icon_role_owner",
    "What Each Rank Can Do" => ":icon_role_operator",
    "Key Rules" => ":icon_rules",
    "Join Restrictions" => ":icon_ban",
    "Speaking Restrictions" => ":icon_mute",
    "Exemptions" => ":icon_tab_exceptions",
    "Registration Required" => ":icon_lock",
    "Password Rules" => ":icon_lock",
    "Restrictions" => ":icon_ban",
    # Channels
    "Channel Autocomplete" => ":icon_btn_search",
    "Channel Expiration" => ":icon_clock",
    "Channel Filtering" => ":icon_btn_search",
    "Channel Management" => ":icon_wrench",
    "Channel Menu" => ":icon_dialog_custom_menus",
    "Channel Messages" => ":icon_chat",
    "Channel Names" => ":icon_channels",
    "Channel Welcome Messages" => ":icon_megaphone",
    "Available Modes" => ":icon_tab_modes",
    "Listing Channels" => ":icon_dialog_channel_list",
    "Popular Channels" => ":icon_star",
    "Joining a Channel" => ":icon_btn_join",
    "Leaving a Channel" => ":icon_btn_remove",
    "Active Channel" => ":icon_tab_channel",
    "Active Channel Suppression" => ":icon_mute",
    "Auto-Join Channels" => ":icon_tab_autojoin",
    "Auto-Join on Invite" => ":icon_dialog_invite",
    # Connection
    "Connection" => ":icon_connect",
    "Connection &amp; Navigation" => ":icon_connect",
    "Connection Banners" => ":icon_megaphone",
    "Connection Flow" => ":icon_websocket",
    "Reconnect Overlay" => ":icon_retry",
    "Intentional Disconnect" => ":icon_close",
    # How-to
    "How to Delete" => ":icon_trash",
    "How to Edit" => ":icon_btn_edit",
    "How to Enable" => ":icon_checkmark",
    "How to Export" => ":icon_btn_export",
    "How to Prevent Expiration" => ":icon_shield",
    "How to Reply" => ":icon_chat",
    "How Registration Works" => ":icon_lock",
    # Managing/Config
    "Managing Ban Exceptions" => ":icon_tab_exceptions",
    "Managing Invite Exceptions" => ":icon_tab_exceptions",
    "Managing Items" => ":icon_wrench",
    "Managing Rules" => ":icon_rules",
    "Managing Timers" => ":icon_clock",
    "Manual Management" => ":icon_wrench",
    "Manual Quality Adjustment" => ":icon_quality_high",
    "Customization" => ":icon_dialog_options",
    "Customizing Responses" => ":icon_dialog_auto_respond",
    "Customizing Settings" => ":icon_dialog_options",
    "Custom Bindings" => ":icon_dialog_cheatsheet",
    "Custom Words" => ":icon_notepad",
    "Global Toggles" => ":icon_tab_control",
    "Enable / Disable" => ":icon_checkmark",
    "Per-Event Flash Toggle" => ":icon_tab_control",
    "Automatic Adaptation" => ":icon_tab_control",
    # Menus/UI
    "Context Menu" => ":icon_dialog_custom_menus",
    "Context Menus" => ":icon_dialog_custom_menus",
    "Conversations" => ":icon_tab_conversations",
    "Conversations Flash" => ":icon_document_alert",
    "Conversations Menu" => ":icon_dialog_custom_menus",
    "Message Menu" => ":icon_dialog_custom_menus",
    "Nick Menu (Chat Area)" => ":icon_dialog_custom_menus",
    "URL Menu" => ":icon_dialog_custom_menus",
    "Menu Types" => ":icon_dialog_custom_menus",
    "Nicklist" => ":icon_tab_nicklist",
    "Compose Bar" => ":icon_notepad",
    "Header" => ":icon_group_tools",
    "Panels" => ":icon_tab_display",
    "Sections" => ":icon_group_view",
    "Three Sections" => ":icon_tab_status",
    "Title Bar Flash" => ":icon_document_alert",
    "UI Element Toggles" => ":icon_group_view",
    "View" => ":icon_group_view",
    "Windows &amp; Dialogs" => ":icon_laptop",
    # P2P/Calls
    "Starting a Call" => ":icon_microphone",
    "Starting a Video Call" => ":icon_camera",
    "End Call" => ":icon_phone_end",
    "Ending" => ":icon_phone_end",
    "Mute/Unmute Microphone" => ":icon_mute",
    "Turn Camera Off/On" => ":icon_camera_off",
    "Picture-in-Picture" => ":icon_pip",
    "Upgrade from Audio to Video" => ":icon_upgrade_video",
    "Quality Indicator" => ":icon_quality_high",
    "Live Switching" => ":icon_devices",
    "Selecting Devices" => ":icon_devices",
    "Device Disconnection" => ":icon_camera_off",
    "Lobby" => ":icon_p2p",
    "Session Types" => ":icon_p2p",
    "P2P" => ":icon_p2p",
    "P2P Actions (registered users only)" => ":icon_p2p",
    "Creating a Session" => ":icon_p2p",
    "Privacy" => ":icon_privacy",
    "Private Mode (TURN-Only)" => ":icon_privacy",
    "Tradeoff" => ":icon_question",
    # Files/Transfer
    "Sending a File" => ":icon_file_send",
    "Receiving" => ":icon_btn_down",
    "Filename Pattern" => ":icon_notepad",
    "Integrity Check" => ":icon_shield",
    "Progress" => ":icon_tab_status",
    "Pause and Resume" => ":icon_clock",
    # Search
    "Search" => ":icon_btn_search",
    "Search Filters" => ":icon_btn_search",
    "Search Navigation" => ":icon_btn_search",
    "Reverse Search (Ctrl+R)" => ":icon_btn_search",
    "Filtering" => ":icon_btn_search",
    "Filtering Rules" => ":icon_btn_search",
    # Notifications
    "Notifications" => ":icon_group_notifications",
    "Notification Channels" => ":icon_tab_notifications",
    "Sound Notifications" => ":icon_dialog_sound",
    "Sound Catalog" => ":icon_dialog_sound",
    "Flood Warning" => ":icon_dialog_flood",
    "Mark All as Read" => ":icon_btn_mark_read",
    "Activating DND" => ":icon_mute",
    "What DND Suppresses" => ":icon_mute",
    "What Still Works" => ":icon_checkmark",
    "Routing Preferences" => ":icon_dialog_notifications",
    # Nicks/Users
    "Nicknames" => ":icon_dialog_nick",
    "Nickname Rules" => ":icon_rules",
    "Nick Autocomplete" => ":icon_btn_search",
    "Nick Expiration" => ":icon_clock",
    "New Nicknames" => ":icon_dialog_nick",
    "Registered Nicknames" => ":icon_lock",
    "User Count" => ":icon_community",
    "User Interactions" => ":icon_community",
    "User Management" => ":icon_wrench",
    "User Modes" => ":icon_tab_modes",
    "User Privilege Modes" => ":icon_tab_modes",
    "Roles" => ":icon_role_operator",
    "Adding Users" => ":icon_btn_add",
    "Using the User List" => ":icon_tab_nicklist",
    "Auto-Whois" => ":icon_tab_contacts",
    # Information
    "What Appears in Status" => ":icon_tab_status",
    ~s(What Counts as "Usage") => ":icon_question",
    "What Happens" => ":icon_question",
    "What Happens When a Nick Expires" => ":icon_clock",
    "Why Register?" => ":icon_question",
    "Why Register a Channel?" => ":icon_question",
    "Why Single Session?" => ":icon_question",
    "Quick Start" => ":icon_lightbulb",
    "Quick Reference" => ":icon_dialog_cheatsheet",
    "Help" => ":icon_question",
    # Dialogs
    "Dialog Contents" => ":icon_dialog_options",
    "Dialog Controls" => ":icon_dialog_options",
    "Dialog Options" => ":icon_dialog_options",
    "Display Options" => ":icon_tab_display",
    "Options" => ":icon_dialog_options",
    "Perform Dialog" => ":icon_dialog_perform",
    "Perform List" => ":icon_dialog_perform",
    # Text/Formatting
    "Color Indicators" => ":icon_palette",
    "Color Palette" => ":icon_palette",
    "Color Thresholds" => ":icon_palette",
    "Text Formatting" => ":icon_notepad",
    "Strip Formatting" => ":icon_close",
    "Using Colors" => ":icon_palette",
    "Methods" => ":icon_code",
    # Time/Sessions
    "Timeouts" => ":icon_clock",
    "Timer Types" => ":icon_clock",
    "Session Expiry" => ":icon_clock",
    "Session Memory" => ":icon_backup",
    "Session Restoration" => ":icon_backup",
    "Execution Order" => ":icon_dialog_perform",
    "Event Types" => ":icon_clock",
    "States" => ":icon_tab_status",
    "Indicators" => ":icon_tab_status",
    "Default" => ":icon_tab_general",
    "Default Behavior" => ":icon_tab_general",
    "Default Thresholds" => ":icon_tab_general",
    "Detail Levels" => ":icon_group_view",
    # Input
    "Input &amp; Autocomplete" => ":icon_terminal",
    "Command Autocomplete" => ":icon_terminal",
    "Argument Completion" => ":icon_terminal",
    "Contextual Placeholder" => ":icon_terminal",
    "Multi-Line Expansion" => ":icon_notepad",
    "Draft-Preserving Navigation" => ":icon_btn_save",
    "Inserting" => ":icon_btn_add",
    "Submitting &amp; Canceling" => ":icon_btn_ok",
    # Misc remaining
    "Sending Notices" => ":icon_megaphone",
    "Visual States" => ":icon_group_view",
    "Visual Format" => ":icon_group_view",
    "Variables" => ":icon_tag",
    "Variable Expansion" => ":icon_tag",
    "Utility" => ":icon_wrench",
    "Keyboard" => ":icon_dialog_cheatsheet",
    "Interaction" => ":icon_community",
    "Ignore Integration" => ":icon_dialog_ignore",
    "Highlighting" => ":icon_dialog_highlight",
    "Emoji" => ":icon_heart",
    "Edited Indicator" => ":icon_btn_edit",
    "Entries" => ":icon_notepad",
    "Export Formats" => ":icon_btn_export",
    "Multiple Kicks" => ":icon_dialog_kick",
    "Operator Actions" => ":icon_role_operator",
    "Apply / OK / Cancel" => ":icon_btn_ok",
    "Cancel" => ":icon_btn_cancel",
    "Clipboard" => ":icon_copy",
    "Common Commands" => ":icon_terminal",
    "Copy Confirmation" => ":icon_copy",
    "Creating Aliases" => ":icon_dialog_alias",
    "Global Announcements" => ":icon_megaphone",
    "Messaging" => ":icon_send",
    "Opening the Notify List" => ":icon_tab_notify",
    "Opening the Ignore List Dialog" => ":icon_dialog_ignore",
    "Opening the Picker" => ":icon_heart",
    "Real-Time Updates" => ":icon_websocket",
    "Replies to Deleted Messages" => ":icon_chat",
    "Disabling Tips" => ":icon_close",
    "Tip Triggers" => ":icon_lightbulb",
    "Tools" => ":icon_group_tools",
    "Wallops" => ":icon_megaphone",
    "URLs" => ":icon_link",
    "URL Catcher" => ":icon_dialog_url",
    "Message of the Day (MOTD)" => ":icon_notepad",
    "Hierarchy" => ":icon_role_owner",
    "Available Formats" => ":icon_notepad",
    "Services" => ":icon_shield",
    "Setting a Quit Message" => ":icon_close",
    "Settings Confirmation" => ":icon_btn_ok",
    "Starting a Conversation" => ":icon_tab_pm",
    "Changing the Format" => ":icon_btn_edit",
    "Key Characteristics" => ":icon_tab_general",
    "Pagination" => ":icon_btn_next",
    "Trigger Events" => ":icon_clock",
  }

  @default_icon ":icon_tab_general"

  def run(files) do
    File.mkdir_p!(@target_dir)

    files_to_convert =
      if files == [] do
        Path.wildcard(Path.join(@source_dir, "*.html"))
      else
        Enum.map(files, &Path.join(@source_dir, &1))
      end

    results =
      Enum.map(files_to_convert, fn source_path ->
        filename = Path.basename(source_path, ".html")
        target_filename = String.replace(filename, "-", "_") <> ".html.heex"
        target_path = Path.join(@target_dir, target_filename)

        html = File.read!(source_path)
        heex = convert(html, filename)
        File.write!(target_path, heex)

        {filename, target_path}
      end)

    IO.puts("Converted #{length(results)} files:")
    Enum.each(results, fn {name, path} -> IO.puts("  #{name} → #{path}") end)
  end

  def convert(html, filename) do
    html
    |> strip_title(filename)
    |> convert_h3_see_also()
    |> convert_h4_headings()
    |> convert_data_help_topic_links()
    |> convert_query_topic_links()
    |> cleanup()
  end

  # Strip the first <h3>...</h3> (the topic title, rendered in template)
  # Special case: ui-toolbar uses <h2> as title
  defp strip_title(html, "ui-toolbar") do
    html
    |> String.replace(~r/<h2>[^<]*<\/h2>\s*/, "", global: false)
  end

  defp strip_title(html, _filename) do
    # Remove only the first h3 (the title)
    String.replace(html, ~r/<h3>[^<]*<\/h3>/, "", global: false)
  end

  # Convert <h3>See Also</h3> → <.help_h4> (ui-toolbar special case)
  defp convert_h3_see_also(html) do
    String.replace(html, "<h3>See Also</h3>", "<.help_h4 icon={:icon_link}>See Also</.help_h4>")
  end

  # Convert <h4>Heading</h4> → <.help_h4 icon={:icon_x}>Heading</.help_h4>
  defp convert_h4_headings(html) do
    Regex.replace(~r/<h4>([^<]+)<\/h4>/, html, fn _full, heading ->
      icon = Map.get(@heading_icons, heading, @default_icon)
      "<.help_h4 icon={#{icon}}>#{heading}</.help_h4>"
    end)
  end

  # Convert <a href="#" data-help-topic="X">Label</a> → <.help_link topic="X">Label</.help_link>
  defp convert_data_help_topic_links(html) do
    Regex.replace(
      ~r/<a\s+href="#"\s*data-help-topic="([^"]+)">(.*?)<\/a>/s,
      html,
      fn _full, topic, label ->
        "<.help_link topic=\"#{topic}\">#{label}</.help_link>"
      end
    )
  end

  # Convert <a href="?topic=X">Label</a> → <.help_link topic="X">Label</.help_link>
  # (used by ui-toolbar.html)
  defp convert_query_topic_links(html) do
    Regex.replace(
      ~r/<a\s+href="\?topic=([^"]+)">(.*?)<\/a>/s,
      html,
      fn _full, topic, label ->
        "<.help_link topic=\"#{topic}\">#{label}</.help_link>"
      end
    )
  end

  # Clean up any trailing whitespace and ensure clean formatting
  defp cleanup(html) do
    html
    |> String.trim()
    |> Kernel.<>("\n")
  end
end

# Parse CLI args
files = System.argv()
HelpConverter.run(files)
