defmodule RetroHexChat.Chat.HelpTopics.Services do
  @moduledoc false

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "nickserv",
        title: "NickServ Overview",
        category: "Services & Protocols",
        keywords: ["nickserv", "register", "identify", "password", "nickname protection"],
        icon: :icon_lock,
        description:
          "Register and protect your nickname with NickServ to prevent others from using it."
      },
      %{
        id: "chanserv",
        title: "ChanServ Overview",
        category: "Services & Protocols",
        keywords: [
          "chanserv",
          "channel service",
          "register channel",
          "access list",
          "channel expiration",
          "channel expiry"
        ],
        icon: :icon_shield,
        description:
          "Register and manage channels with ChanServ, including access lists and channel settings."
      }
    ]
  end
end
