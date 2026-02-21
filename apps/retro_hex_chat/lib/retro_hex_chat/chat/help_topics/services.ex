defmodule RetroHexChat.Chat.HelpTopics.Services do
  @moduledoc false

  @help_dir Path.join(:code.priv_dir(:retro_hex_chat), "help")

  @external_resource Path.join(@help_dir, "nickserv.html")
  @external_resource Path.join(@help_dir, "chanserv.html")

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "nickserv",
        title: "NickServ Overview",
        category: "Services",
        keywords: ["nickserv", "register", "identify", "password", "nickname protection"],
        content: File.read!(Path.join(@help_dir, "nickserv.html"))
      },
      %{
        id: "chanserv",
        title: "ChanServ Overview",
        category: "Services",
        keywords: [
          "chanserv",
          "channel service",
          "register channel",
          "access list",
          "channel expiration",
          "channel expiry"
        ],
        content: File.read!(Path.join(@help_dir, "chanserv.html"))
      }
    ]
  end
end
