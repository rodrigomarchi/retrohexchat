defmodule RetroHexChat.SessionControlTest do
  @moduledoc """
  What a forced disconnect reaches, and what it deliberately does not.

  The two scopes exist so a call, a space or a game can live in a second browser
  tab: a chat takeover must end the previous chat and leave those alone, while a
  ban must end everything the person has open.

  Each test subscribes to exactly one topic, so an assertion says which topic
  delivered and not merely how many messages arrived.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.{SessionControl, Topics}

  setup do
    %{nickname: "nick_#{System.unique_integer([:positive])}"}
  end

  describe "scope :chat" do
    test "ends the chat session", %{nickname: nickname} do
      subscribe(Topics.inbox(nickname))

      SessionControl.disconnect(nickname, %{reason: "taken over"}, :chat)

      assert_receive {:force_disconnect, %{reason: "taken over", scope: :chat}}
    end

    test "leaves a satellite surface alone", %{nickname: nickname} do
      subscribe(Topics.surfaces(nickname))

      SessionControl.disconnect(nickname, %{reason: "taken over"}, :chat)

      refute_receive {:force_disconnect, _payload}
    end
  end

  describe "scope :all" do
    test "ends the chat session", %{nickname: nickname} do
      subscribe(Topics.inbox(nickname))

      SessionControl.disconnect(nickname, %{reason: "banned"}, :all)

      assert_receive {:force_disconnect, %{reason: "banned", scope: :all}}
    end

    test "ends every satellite surface", %{nickname: nickname} do
      subscribe(Topics.surfaces(nickname))

      SessionControl.disconnect(nickname, %{reason: "banned"}, :all)

      assert_receive {:force_disconnect, %{reason: "banned", scope: :all}}
    end

    test "is the default, because every domain caller means all of them", %{nickname: nickname} do
      subscribe(Topics.surfaces(nickname))

      SessionControl.disconnect(nickname, %{reason: "banned"})

      assert_receive {:force_disconnect, %{scope: :all}}
    end
  end

  test "the caller's payload survives, keys and all", %{nickname: nickname} do
    subscribe(Topics.inbox(nickname))

    SessionControl.disconnect(nickname, %{reason: "nuked", skip_whowas: true, system_nuke: true})

    assert_receive {:force_disconnect, payload}
    assert payload.skip_whowas
    assert payload.system_nuke
  end

  # The scope decides which door the message goes through, so a payload key of
  # the same name must not be able to contradict it.
  test "a caller cannot smuggle a wider scope through the payload", %{nickname: nickname} do
    subscribe(Topics.surfaces(nickname))

    SessionControl.disconnect(nickname, %{reason: "taken over", scope: :all}, :chat)

    refute_receive {:force_disconnect, _payload}
  end

  defp subscribe(topic), do: :ok = Phoenix.PubSub.subscribe(RetroHexChat.PubSub, topic)
end
