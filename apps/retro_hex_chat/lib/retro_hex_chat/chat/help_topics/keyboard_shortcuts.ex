defmodule RetroHexChat.Chat.HelpTopics.KeyboardShortcuts do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "keyboard-shortcuts",
        title: dgettext("help", "Keyboard Shortcuts"),
        category: dgettext("help", "User Interface"),
        keywords: [
          "keyboard",
          "shortcuts",
          "hotkeys",
          "keybindings",
          "keys",
          "me",
          dgettext("help", "user lookup")
        ],
        icon: :icon_dialog_cheatsheet,
        description:
          dgettext(
            "help",
            "Complete reference of keyboard shortcuts for navigation, messaging, and interface control."
          )
      }
    ]
  end
end
