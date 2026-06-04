defmodule RetroHexChat.Chat.HelpTopics.Services do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "nickserv",
        title: dgettext("help", "NickServ Overview"),
        category: dgettext("help", "Services & Protocols"),
        keywords: [
          "nickserv",
          "register",
          "identify",
          "account",
          "login",
          "ghost",
          "drop",
          "unregister",
          "away",
          "bio",
          "password",
          dgettext("help", "nickname protection")
        ],
        icon: :icon_lock,
        description:
          dgettext(
            "help",
            "Register and protect your nickname with NickServ to prevent others from using it."
          )
      },
      %{
        id: "chanserv",
        title: dgettext("help", "ChanServ Overview"),
        category: dgettext("help", "Services & Protocols"),
        keywords: [
          "chanserv",
          dgettext("help", "channel service"),
          dgettext("help", "register channel"),
          dgettext("help", "access list"),
          dgettext("help", "channel expiration"),
          dgettext("help", "channel expiry")
        ],
        icon: :icon_shield,
        description:
          dgettext(
            "help",
            "Register and manage channels with ChanServ, including access lists and channel settings."
          )
      }
    ]
  end
end
