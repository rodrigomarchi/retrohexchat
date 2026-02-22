defmodule RetroHexChat.Chat.HelpTopics.KeyboardShortcuts do
  @moduledoc false

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "keyboard-shortcuts",
        title: "Keyboard Shortcuts",
        category: "Keyboard Shortcuts",
        keywords: ["keyboard", "shortcuts", "hotkeys", "keybindings", "keys"],
        icon: :icon_dialog_cheatsheet,
        description:
          "Complete reference of keyboard shortcuts for navigation, messaging, and interface control."
      }
    ]
  end
end
