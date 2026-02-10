# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# RetroHexChat channels are ephemeral OTP processes managed by
# RetroHexChat.Channels.Supervisor / RetroHexChat.Channels.Server.
# The #lobby channel is created on-demand when the first user connects
# (ChatLive.join_channel/3 calls ensure_channel_exists/1).
#
# No database seeding is required for channels. Message history is
# persisted to the messages table automatically as users chat.
#
# If you need to pre-populate test data, you can do so here:
#
#     RetroHexChat.Repo.insert!(%RetroHexChat.Chat.Message{
#       channel_name: "#lobby",
#       author_nickname: "System",
#       content: "Welcome to RetroHexChat!",
#       type: "system"
#     })
