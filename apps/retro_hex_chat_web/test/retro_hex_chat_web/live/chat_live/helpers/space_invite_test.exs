defmodule RetroHexChatWeb.ChatLive.Helpers.SpaceInviteTest do
  use RetroHexChatWeb.ConnCase, async: false

  alias RetroHexChat.Chat.Queries
  alias RetroHexChatWeb.ChatLive.Helpers.SpaceInvite

  @moduletag :integration

  describe "publish_invite/2" do
    test "persists a space_invite message in the target channel" do
      channel = "#space-inv-#{System.unique_integer([:positive])}"

      assert {:ok, message} =
               SpaceInvite.publish_invite("alice", %{
                 target: channel,
                 token: "tok-abc",
                 title: "Guild Tavern",
                 creator_id: 1
               })

      assert message.type == "space_invite"
      assert message.channel_name == channel
      assert message.author_nickname == "alice"
      assert message.content =~ "/space/tok-abc"

      [persisted | _] = Queries.list_messages(channel, limit: 1)
      assert persisted.id == message.id
      assert persisted.type == "space_invite"
    end
  end

  describe "invite_content/1" do
    test "contains the textual /space/<token> fallback" do
      assert SpaceInvite.invite_content("tok-xyz") =~ "/space/tok-xyz"
    end
  end
end
