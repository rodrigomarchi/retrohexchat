defmodule RetroHexChat.Chat.HelpTopics.Services do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "nickserv",
        title: gettext("NickServ Overview"),
        category: gettext("Services & Protocols"),
        keywords: ["nickserv", "register", "identify", "password", gettext("nickname protection")],
        icon: :icon_lock,
        description:
          gettext(
            "Register and protect your nickname with NickServ to prevent others from using it."
          )
      },
      %{
        id: "chanserv",
        title: gettext("ChanServ Overview"),
        category: gettext("Services & Protocols"),
        keywords: [
          "chanserv",
          gettext("channel service"),
          gettext("register channel"),
          gettext("access list"),
          gettext("channel expiration"),
          gettext("channel expiry")
        ],
        icon: :icon_shield,
        description:
          gettext(
            "Register and manage channels with ChanServ, including access lists and channel settings."
          )
      }
    ]
  end
end
