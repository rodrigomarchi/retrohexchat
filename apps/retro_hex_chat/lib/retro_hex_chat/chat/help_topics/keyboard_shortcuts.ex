defmodule RetroHexChat.Chat.HelpTopics.KeyboardShortcuts do
  @moduledoc false

  # credo:disable-for-this-file Credo.Check.Readability.StringSigils

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "keyboard-shortcuts",
        title: "Keyboard Shortcuts",
        category: "Keyboard Shortcuts",
        keywords: ["keyboard", "shortcuts", "hotkeys", "keybindings", "keys"],
        content:
          "<h3>Keyboard Shortcuts</h3>" <>
            "<h4>Navigation</h4>" <>
            "<pre>Ctrl+Shift+/    — Shortcut Cheatsheet\nCtrl+Shift+F    — Find / Search\nCtrl+Shift+]    — Next Window\nCtrl+Shift+[    — Previous Window\nCtrl+Shift+1..9 — Switch to Window 1-9\nEscape          — Close search bar / dialog</pre>" <>
            "<h4>Windows &amp; Dialogs</h4>" <>
            "<pre>Ctrl+Shift+A  — Address Book\nCtrl+Shift+H  — Highlight Words\nCtrl+Shift+G  — Ignore List\nCtrl+Shift+L  — Log Viewer\nCtrl+Shift+O  — Options\nCtrl+Shift+E  — Perform Dialog\nCtrl+Shift+S  — URL Catcher\nCtrl+Shift+W  — Help</pre>" <>
            "<h4>Clipboard</h4>" <>
            "<pre>Ctrl+C        — Copy selected text</pre>" <>
            "<h4>Text Formatting</h4>" <>
            "<pre>Ctrl+Shift+B  — Bold\nCtrl+Shift+Y  — Italic\nCtrl+Shift+U  — Underline\nCtrl+Shift+D  — Color\nCtrl+Shift+V  — Reverse\nCtrl+Shift+X  — Reset formatting</pre>" <>
            "<h4>Input &amp; Autocomplete</h4>" <>
            "<pre>Enter         — Send message / select autocomplete item\nShift+Enter   — Insert newline in input\nUp / Down     — Command history / navigate autocomplete dropdown\nCtrl+Up       — Browse history (saves draft)\nCtrl+Down     — Browse history forward (restores draft)\nCtrl+R        — Reverse search history\nTab           — Select autocomplete item / cycle nick completion\nEscape        — Dismiss autocomplete / tooltip / history search\n/             — Open command autocomplete (at start of input)\n@             — Open nick autocomplete (at word boundary)\n#             — Open channel autocomplete (at word boundary)</pre>" <>
            "<h4>Context Menus</h4>" <>
            "<pre>Arrow Down    — Next menu item\nArrow Up      — Previous menu item\nEnter         — Select focused menu item\nEscape        — Close context menu</pre>" <>
            "<h4>Search Navigation</h4>" <>
            "<pre>Arrow Down    — Next search result (in search bar)\nArrow Up      — Previous search result (in search bar)</pre>" <>
            "<h4>Emoji</h4>" <>
            "<pre>Emoji Picker  — Click smiley button in formatting toolbar</pre>" <>
            "<h4>Customization</h4>" <>
            "<p>All keyboard shortcuts (except Escape) can be customized in <strong>Options &gt; Key Bindings</strong> (Ctrl+Shift+O). " <>
            "Press <strong>Ctrl+Shift+/</strong> to see a quick reference of all current bindings. " <>
            "See <a href=\"#\" data-help-topic=\"feature-key-bindings\">Key Bindings</a> for details.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-cheatsheet\">Shortcut Cheatsheet</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-autocomplete\">Autocomplete</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-command-syntax-tooltip\">Command Syntax Tooltip</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-enhanced-history\">Enhanced History</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-search\">Search</a></p>"
      }
    ]
  end
end
