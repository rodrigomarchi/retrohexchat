defmodule RetroHexChatWeb.ChatLive.ChatTitleTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Accounts.Session
  alias RetroHexChatWeb.ChatLive.ChatTitle

  defp session(fields \\ []), do: struct!(Session.new("Troll"), fields)

  describe "conversation/2" do
    test "names the active channel" do
      assert ChatTitle.conversation(session(active_channel: "#lobby"), false) == "#lobby"
    end

    test "the active PM wins over the channel behind it" do
      session = session(active_channel: "#lobby", active_pm: "Joe")

      assert ChatTitle.conversation(session, false) == "Joe"
    end

    test "the status tab wins over the conversation the session still points at" do
      session = session(active_channel: "#lobby", active_pm: "Joe")

      assert ChatTitle.conversation(session, true) == "Status"
    end

    test "falls back to the status label with nothing open" do
      assert ChatTitle.conversation(session(), false) == "Status"
    end
  end

  describe "window_title/2" do
    test "a channel reads #channel[nick]" do
      assert ChatTitle.window_title(session(active_channel: "#lobby"), false) == "#lobby[Troll]"
    end

    test "a PM reads remote:mine" do
      session = session(active_channel: "#lobby", active_pm: "Joe")

      assert ChatTitle.window_title(session, false) == "Joe:Troll"
    end

    test "the status tab keeps the bracket form" do
      session = session(active_channel: "#lobby", active_pm: "Joe")

      assert ChatTitle.window_title(session, true) == "Status[Troll]"
    end

    test "falls back to the application name before the session is named" do
      assert ChatTitle.window_title(%{Session.new("Troll") | nickname: ""}, false) ==
               "RetroHexChat"
    end
  end

  describe "document_title/2" do
    test "the browser tab and the window name the same thing" do
      for {session, status_tab?} <- [
            {session(active_channel: "#lobby"), false},
            {session(active_pm: "Joe"), false},
            {session(active_channel: "#lobby"), true}
          ] do
        assert ChatTitle.document_title(session, status_tab?) ==
                 ChatTitle.window_title(session, status_tab?)
      end
    end
  end

  describe "window_meta/2" do
    test "a channel shows the identity state and the member count" do
      session = session(active_channel: "#lobby", identified: true)

      assert ChatTitle.window_meta(session, 3) == "Identified · 3"
    end

    test "a PM has no member count" do
      session = session(active_pm: "Joe", identified: true)

      assert ChatTitle.window_meta(session, 3) == "Identified"
    end

    test "an empty channel shows the state alone" do
      assert ChatTitle.window_meta(session(active_channel: "#lobby"), 0) == "Guest"
    end

    test "away wins over identified, as in the status bar" do
      session = session(active_channel: "#lobby", identified: true, away: true)

      assert ChatTitle.window_meta(session, 2) == "Away · 2"
    end
  end
end
