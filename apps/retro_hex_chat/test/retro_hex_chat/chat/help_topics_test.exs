defmodule RetroHexChat.Chat.HelpTopicsTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.HelpTopics

  @moduletag :unit

  describe "all_topics/0" do
    test "returns a non-empty list" do
      assert [_ | _] = HelpTopics.all_topics()
    end

    test "every topic has required fields" do
      for topic <- HelpTopics.all_topics() do
        assert is_binary(topic.id) and topic.id != ""
        assert is_binary(topic.title) and topic.title != ""
        assert is_binary(topic.category) and topic.category != ""
        assert is_binary(topic.content) and topic.content != ""
        assert is_list(topic.keywords) and topic.keywords != []
      end
    end

    test "topic ids are unique" do
      ids = Enum.map(HelpTopics.all_topics(), & &1.id)
      assert length(ids) == length(Enum.uniq(ids))
    end
  end

  describe "get_topic/1" do
    test "returns a topic by id" do
      topic = HelpTopics.get_topic("welcome")
      assert topic.id == "welcome"
      assert topic.title == "Welcome to RetroHexChat"
    end

    test "returns nil for unknown id" do
      assert HelpTopics.get_topic("nonexistent") == nil
    end
  end

  describe "topics_by_category/0" do
    test "returns categories in display order" do
      categories = HelpTopics.topics_by_category()
      assert is_list(categories)

      names = Enum.map(categories, &elem(&1, 0))
      assert "Getting Started" in names
      assert "Commands" in names
      assert "Services" in names
      assert "Channel Modes" in names
      assert "Text Formatting" in names
      assert "Features" in names
      assert "User Interface" in names
      assert "Keyboard Shortcuts" in names
    end

    test "every category has at least one topic" do
      for {_name, topics} <- HelpTopics.topics_by_category() do
        assert [_ | _] = topics
      end
    end

    test "categories cover all topics" do
      category_topics =
        HelpTopics.topics_by_category()
        |> Enum.flat_map(&elem(&1, 1))

      assert Enum.count(category_topics) == Enum.count(HelpTopics.all_topics())
    end
  end

  describe "search/1" do
    test "returns empty list for queries shorter than 2 chars" do
      assert HelpTopics.search("") == []
      assert HelpTopics.search("a") == []
    end

    test "finds topics by title" do
      results = HelpTopics.search("join")
      ids = Enum.map(results, & &1.id)
      assert "cmd-join" in ids
    end

    test "finds topics by keyword" do
      results = HelpTopics.search("buddy")
      ids = Enum.map(results, & &1.id)
      assert "feature-notify-list" in ids
    end

    test "finds topics by content" do
      results = HelpTopics.search("operator")
      assert results != []
    end

    test "search is case-insensitive" do
      lower = HelpTopics.search("join")
      upper = HelpTopics.search("JOIN")
      assert Enum.map(lower, & &1.id) == Enum.map(upper, & &1.id)
    end
  end

  describe "feature-channel-central topic" do
    test "exists with correct id and category" do
      topic = HelpTopics.get_topic("feature-channel-central")
      assert topic != nil
      assert topic.id == "feature-channel-central"
      assert topic.category == "Features"
    end

    test "has correct title" do
      topic = HelpTopics.get_topic("feature-channel-central")
      assert topic.title == "Channel Central"
    end

    test "has non-empty content with key information" do
      topic = HelpTopics.get_topic("feature-channel-central")
      assert topic.content != ""
      assert topic.content =~ "tabbed"
      assert topic.content =~ "General"
      assert topic.content =~ "Modes"
      assert topic.content =~ "Bans"
      assert topic.content =~ "Ban Exceptions"
      assert topic.content =~ "Invite Exceptions"
      assert topic.content =~ "Double-click"
      assert topic.content =~ "Tools"
    end

    test "has non-empty keywords" do
      topic = HelpTopics.get_topic("feature-channel-central")
      assert topic.keywords != []
    end
  end

  describe "feature-ban-exceptions topic" do
    test "exists with correct id and category" do
      topic = HelpTopics.get_topic("feature-ban-exceptions")
      assert topic != nil
      assert topic.id == "feature-ban-exceptions"
      assert topic.category == "Features"
    end

    test "has correct title" do
      topic = HelpTopics.get_topic("feature-ban-exceptions")
      assert topic.title == "Ban Exceptions (+e)"
    end

    test "has non-empty content with key information" do
      topic = HelpTopics.get_topic("feature-ban-exceptions")
      assert topic.content != ""
      assert topic.content =~ "bypass channel bans"
      assert topic.content =~ "Ban Exceptions"
      assert topic.content =~ "Channel Central"
      assert topic.content =~ "operator"
    end

    test "has non-empty keywords" do
      topic = HelpTopics.get_topic("feature-ban-exceptions")
      assert topic.keywords != []
    end
  end

  describe "feature-invite-exceptions topic" do
    test "exists with correct id and category" do
      topic = HelpTopics.get_topic("feature-invite-exceptions")
      assert topic != nil
      assert topic.id == "feature-invite-exceptions"
      assert topic.category == "Features"
    end

    test "has correct title" do
      topic = HelpTopics.get_topic("feature-invite-exceptions")
      assert topic.title == "Invite Exceptions (+I)"
    end

    test "has non-empty content with key information" do
      topic = HelpTopics.get_topic("feature-invite-exceptions")
      assert topic.content != ""
      assert topic.content =~ "invite-only"
      assert topic.content =~ "Invite Exceptions"
      assert topic.content =~ "Channel Central"
      assert topic.content =~ "+i"
    end

    test "has non-empty keywords" do
      topic = HelpTopics.get_topic("feature-invite-exceptions")
      assert topic.keywords != []
    end
  end

  describe "cmd-perform topic" do
    test "exists with correct id and category" do
      topic = HelpTopics.get_topic("cmd-perform")
      assert topic != nil
      assert topic.id == "cmd-perform"
      assert topic.category == "Commands"
    end

    test "has correct title" do
      topic = HelpTopics.get_topic("cmd-perform")
      assert topic.title == "/perform"
    end

    test "content covers key functionality" do
      topic = HelpTopics.get_topic("cmd-perform")
      assert topic.content =~ "list"
      assert topic.content =~ "add"
      assert topic.content =~ "remove"
      assert topic.content =~ "move"
      assert topic.content =~ "clear"
      assert topic.content =~ "sequentially"
      assert topic.content =~ "masked"
    end

    test "cross-references related topics" do
      topic = HelpTopics.get_topic("cmd-perform")
      assert topic.content =~ "cmd-autojoin"
      assert topic.content =~ "feature-perform"
    end

    test "has non-empty keywords" do
      topic = HelpTopics.get_topic("cmd-perform")
      assert topic.keywords != []
    end
  end

  describe "cmd-autojoin topic" do
    test "exists with correct id and category" do
      topic = HelpTopics.get_topic("cmd-autojoin")
      assert topic != nil
      assert topic.id == "cmd-autojoin"
      assert topic.category == "Commands"
    end

    test "has correct title" do
      topic = HelpTopics.get_topic("cmd-autojoin")
      assert topic.title == "/autojoin"
    end

    test "content covers key functionality" do
      topic = HelpTopics.get_topic("cmd-autojoin")
      assert topic.content =~ "list"
      assert topic.content =~ "add"
      assert topic.content =~ "remove"
      assert topic.content =~ "clear"
      assert topic.content =~ "#channel"
      assert topic.content =~ "key"
    end

    test "cross-references related topics" do
      topic = HelpTopics.get_topic("cmd-autojoin")
      assert topic.content =~ "cmd-perform"
      assert topic.content =~ "cmd-join"
    end

    test "has non-empty keywords" do
      topic = HelpTopics.get_topic("cmd-autojoin")
      assert topic.keywords != []
    end
  end

  describe "feature-perform topic" do
    test "exists with correct id and category" do
      topic = HelpTopics.get_topic("feature-perform")
      assert topic != nil
      assert topic.id == "feature-perform"
      assert topic.category == "Features"
    end

    test "has correct title" do
      topic = HelpTopics.get_topic("feature-perform")
      assert topic.title == "Perform / Auto-Commands"
    end

    test "content covers key functionality" do
      topic = HelpTopics.get_topic("feature-perform")
      assert topic.content =~ "Perform"
      assert topic.content =~ "auto-join"
      assert topic.content =~ "Ctrl+Shift+E"
      assert topic.content =~ "Enable"
      assert topic.content =~ "Execution Order"
    end

    test "cross-references related topics" do
      topic = HelpTopics.get_topic("feature-perform")
      assert topic.content =~ "cmd-perform"
      assert topic.content =~ "cmd-autojoin"
      assert topic.content =~ "feature-auto-reconnect"
    end

    test "has non-empty keywords" do
      topic = HelpTopics.get_topic("feature-perform")
      assert topic.keywords != []
    end
  end

  describe "feature-auto-reconnect topic" do
    test "exists with correct id and category" do
      topic = HelpTopics.get_topic("feature-auto-reconnect")
      assert topic != nil
      assert topic.id == "feature-auto-reconnect"
      assert topic.category == "Features"
    end

    test "has correct title" do
      topic = HelpTopics.get_topic("feature-auto-reconnect")
      assert topic.title == "Auto-Reconnect"
    end

    test "content covers key functionality" do
      topic = HelpTopics.get_topic("feature-auto-reconnect")
      assert topic.content =~ "exponential backoff"
      assert topic.content =~ "10 attempts"
      assert topic.content =~ "Cancel"
      assert topic.content =~ "/quit"
      assert topic.content =~ "Session Restoration"
    end

    test "cross-references related topics" do
      topic = HelpTopics.get_topic("feature-auto-reconnect")
      assert topic.content =~ "feature-perform"
    end

    test "has non-empty keywords" do
      topic = HelpTopics.get_topic("feature-auto-reconnect")
      assert topic.keywords != []
    end
  end

  describe "keyboard shortcuts includes Ctrl+Shift+E for Perform" do
    test "Ctrl+Shift+E is listed in keyboard shortcuts" do
      topic = HelpTopics.get_topic("keyboard-shortcuts")
      assert topic.content =~ "Ctrl+Shift+E"
      assert topic.content =~ "Perform Dialog"
    end
  end

  describe "all_keywords/0" do
    test "returns a sorted list of {keyword, topic_id}" do
      keywords = HelpTopics.all_keywords()
      assert is_list(keywords)
      assert keywords != []

      for {kw, id} <- keywords do
        assert is_binary(kw)
        assert is_binary(id)
      end
    end

    test "keywords are sorted alphabetically" do
      keywords = HelpTopics.all_keywords()
      kw_strings = Enum.map(keywords, &elem(&1, 0))
      assert kw_strings == Enum.sort(kw_strings)
    end

    test "every keyword points to a valid topic" do
      valid_ids = MapSet.new(HelpTopics.all_topics(), & &1.id)

      for {_kw, id} <- HelpTopics.all_keywords() do
        assert MapSet.member?(valid_ids, id), "keyword points to unknown topic: #{id}"
      end
    end
  end

  describe "feature-log-viewer topic" do
    test "exists with correct id and category" do
      topic = HelpTopics.get_topic("feature-log-viewer")
      assert topic != nil
      assert topic.id == "feature-log-viewer"
      assert topic.category == "Features"
    end

    test "has correct title" do
      topic = HelpTopics.get_topic("feature-log-viewer")
      assert topic.title == "Log Viewer"
    end

    test "content covers key functionality" do
      topic = HelpTopics.get_topic("feature-log-viewer")
      assert topic.content =~ "Ctrl+Shift+L"
      assert topic.content =~ "Source"
      assert topic.content =~ "Date Range"
      assert topic.content =~ "Nickname"
      assert topic.content =~ "Pagination"
    end

    test "cross-references log export topic" do
      topic = HelpTopics.get_topic("feature-log-viewer")
      assert topic.content =~ "feature-log-export"
    end
  end

  describe "feature-log-export topic" do
    test "exists with correct id and category" do
      topic = HelpTopics.get_topic("feature-log-export")
      assert topic != nil
      assert topic.id == "feature-log-export"
      assert topic.category == "Features"
    end

    test "has correct title" do
      topic = HelpTopics.get_topic("feature-log-export")
      assert topic.title == "Log Export"
    end

    test "content covers export formats" do
      topic = HelpTopics.get_topic("feature-log-export")
      assert topic.content =~ ".txt"
      assert topic.content =~ ".html"
    end

    test "cross-references log viewer topic" do
      topic = HelpTopics.get_topic("feature-log-export")
      assert topic.content =~ "feature-log-viewer"
    end
  end

  describe "keyboard shortcuts includes Ctrl+Shift+L for Log Viewer" do
    test "Ctrl+Shift+L is listed in keyboard shortcuts" do
      topic = HelpTopics.get_topic("keyboard-shortcuts")
      assert topic.content =~ "Ctrl+Shift+L"
      assert topic.content =~ "Log Viewer"
    end
  end

  describe "status bar help topic" do
    test "topic exists" do
      topic = HelpTopics.get_topic("feature-status-bar")
      assert topic != nil
      assert topic.title == "Status Bar"
      assert topic.category == "Features"
    end

    test "content describes three sections" do
      topic = HelpTopics.get_topic("feature-status-bar")
      assert topic.content =~ "Left"
      assert topic.content =~ "Center"
      assert topic.content =~ "Right"
    end

    test "cross-references lag and connection topics" do
      topic = HelpTopics.get_topic("feature-status-bar")
      assert topic.content =~ "feature-lag-indicator"
      assert topic.content =~ "feature-connection-states"
    end
  end

  describe "lag indicator help topic" do
    test "topic exists" do
      topic = HelpTopics.get_topic("feature-lag-indicator")
      assert topic != nil
      assert topic.title == "Lag Indicator"
    end

    test "content describes color thresholds" do
      topic = HelpTopics.get_topic("feature-lag-indicator")
      assert topic.content =~ "200ms"
      assert topic.content =~ "500ms"
      assert topic.content =~ "Timeout"
    end

    test "cross-references status bar" do
      topic = HelpTopics.get_topic("feature-lag-indicator")
      assert topic.content =~ "feature-status-bar"
    end
  end

  describe "P2P help topics" do
    test "P2P Sessions topic exists with correct category" do
      topic = HelpTopics.get_topic("feature-p2p-sessions")
      assert topic != nil
      assert topic.category == "Features"
      assert topic.title == "Sessoes P2P"
    end

    test "P2P Sessions content covers key functionality" do
      topic = HelpTopics.get_topic("feature-p2p-sessions")
      assert topic.content =~ "/p2p"
      assert topic.content =~ "/call"
      assert topic.content =~ "/sendfile"
      assert topic.content =~ "lobby"
      assert topic.content =~ "consentimento bilateral"
    end

    test "P2P Sessions cross-references related topics" do
      topic = HelpTopics.get_topic("feature-p2p-sessions")
      assert topic.content =~ "feature-file-transfer"
      assert topic.content =~ "feature-audio-call"
      assert topic.content =~ "feature-privacy-settings"
    end

    test "File Transfer topic exists with correct category" do
      topic = HelpTopics.get_topic("feature-file-transfer")
      assert topic != nil
      assert topic.category == "Features"
      assert topic.title == "Transferencia de Arquivos"
    end

    test "File Transfer content covers key functionality" do
      topic = HelpTopics.get_topic("feature-file-transfer")
      assert topic.content =~ "/sendfile"
      assert topic.content =~ "SHA-256"
      assert topic.content =~ "DataChannel"
    end

    test "File Transfer cross-references P2P Sessions" do
      topic = HelpTopics.get_topic("feature-file-transfer")
      assert topic.content =~ "feature-p2p-sessions"
    end

    test "Privacy Settings topic exists with correct category" do
      topic = HelpTopics.get_topic("feature-privacy-settings")
      assert topic != nil
      assert topic.category == "Features"
      assert topic.title == "Configuracoes de Privacidade"
    end

    test "Privacy Settings content covers key functionality" do
      topic = HelpTopics.get_topic("feature-privacy-settings")
      assert topic.content =~ "TURN"
      assert topic.content =~ "relay"
      assert topic.content =~ "IP"
      assert topic.content =~ "Modo privado"
    end

    test "Privacy Settings cross-references related topics" do
      topic = HelpTopics.get_topic("feature-privacy-settings")
      assert topic.content =~ "feature-p2p-sessions"
      assert topic.content =~ "feature-audio-call"
    end

    test "command topics exist for P2P commands" do
      for id <- ~w(cmd-p2p cmd-call cmd-sendfile) do
        topic = HelpTopics.get_topic(id)
        assert topic != nil, "Missing help topic: #{id}"
        assert topic.category == "Commands"
        assert topic.content =~ "feature-p2p-sessions"
      end
    end

    test "audio call topic cross-references P2P Sessions and Privacy" do
      topic = HelpTopics.get_topic("feature-audio-call")
      assert topic.content =~ "feature-p2p-sessions"
      assert topic.content =~ "feature-privacy-settings"
    end

    test "video call topic cross-references P2P Sessions and Privacy" do
      topic = HelpTopics.get_topic("feature-video-call")
      assert topic.content =~ "feature-p2p-sessions"
      assert topic.content =~ "feature-privacy-settings"
    end
  end

  describe "connection states help topic" do
    test "topic exists" do
      topic = HelpTopics.get_topic("feature-connection-states")
      assert topic != nil
      assert topic.title == "Connection States"
    end

    test "content describes four states" do
      topic = HelpTopics.get_topic("feature-connection-states")
      assert topic.content =~ "Connected"
      assert topic.content =~ "Connecting"
      assert topic.content =~ "Disconnected"
      assert topic.content =~ "Reconnecting"
    end

    test "content describes banners" do
      topic = HelpTopics.get_topic("feature-connection-states")
      assert topic.content =~ "banner"
    end

    test "cross-references status bar and lag" do
      topic = HelpTopics.get_topic("feature-connection-states")
      assert topic.content =~ "feature-status-bar"
      assert topic.content =~ "feature-lag-indicator"
    end
  end

  describe "HTML file integrity" do
    @help_dir Path.join(:code.priv_dir(:retro_hex_chat), "help")

    test "every topic ID has a corresponding .html file" do
      for topic <- HelpTopics.all_topics() do
        path = Path.join(@help_dir, "#{topic.id}.html")
        assert File.exists?(path), "Missing HTML file for topic: #{topic.id}"
      end
    end

    test "no .html files without a corresponding topic" do
      topic_ids = MapSet.new(HelpTopics.all_topics(), & &1.id)

      @help_dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".html"))
      |> Enum.each(fn file ->
        id = String.replace_suffix(file, ".html", "")

        assert MapSet.member?(topic_ids, id), "Orphan HTML file: #{file}"
      end)
    end

    test "no empty content fields" do
      for topic <- HelpTopics.all_topics() do
        assert String.trim(topic.content) != "",
               "Empty content for topic: #{topic.id}"
      end
    end
  end
end
