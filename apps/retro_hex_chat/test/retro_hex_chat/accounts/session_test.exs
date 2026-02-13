defmodule RetroHexChat.Accounts.SessionTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Accounts.Session

  describe "new/1" do
    test "creates a session with the given nickname" do
      session = Session.new("Rodrigo")
      assert session.nickname == "Rodrigo"
    end

    test "initializes with empty channels list" do
      session = Session.new("Rodrigo")
      assert session.channels == []
    end

    test "initializes with nil active_channel" do
      session = Session.new("Rodrigo")
      assert session.active_channel == nil
    end

    test "initializes as not identified" do
      session = Session.new("Rodrigo")
      assert session.identified == false
    end

    test "sets connected_at to a DateTime" do
      session = Session.new("Rodrigo")
      assert %DateTime{} = session.connected_at
    end

    test "initializes as not away" do
      session = Session.new("Rodrigo")
      assert session.away == false
      assert session.away_message == nil
    end
  end

  describe "update_nickname/2" do
    test "changes the nickname" do
      session = Session.new("OldNick")
      updated = Session.update_nickname(session, "NewNick")
      assert updated.nickname == "NewNick"
    end

    test "preserves other fields" do
      session = Session.new("OldNick") |> Session.set_identified(true)
      updated = Session.update_nickname(session, "NewNick")
      assert updated.identified == true
    end
  end

  describe "add_channel/2" do
    test "adds a channel to the list" do
      session = Session.new("Rodrigo")
      updated = Session.add_channel(session, "#general")
      assert updated.channels == ["#general"]
    end

    test "appends channels in order" do
      session =
        Session.new("Rodrigo")
        |> Session.add_channel("#general")
        |> Session.add_channel("#random")

      assert session.channels == ["#general", "#random"]
    end

    test "does not add duplicate channels" do
      session =
        Session.new("Rodrigo")
        |> Session.add_channel("#general")
        |> Session.add_channel("#general")

      assert session.channels == ["#general"]
    end
  end

  describe "remove_channel/2" do
    test "removes a channel from the list" do
      session =
        Session.new("Rodrigo")
        |> Session.add_channel("#general")
        |> Session.add_channel("#random")
        |> Session.remove_channel("#general")

      assert session.channels == ["#random"]
    end

    test "resets active_channel when the active channel is removed" do
      session =
        Session.new("Rodrigo")
        |> Session.add_channel("#general")
        |> Session.add_channel("#random")
        |> Session.set_active_channel("#general")
        |> Session.remove_channel("#general")

      assert session.active_channel == "#random"
    end

    test "sets active_channel to nil when last channel is removed" do
      session =
        Session.new("Rodrigo")
        |> Session.add_channel("#general")
        |> Session.set_active_channel("#general")
        |> Session.remove_channel("#general")

      assert session.active_channel == nil
    end

    test "keeps active_channel unchanged when removing a different channel" do
      session =
        Session.new("Rodrigo")
        |> Session.add_channel("#general")
        |> Session.add_channel("#random")
        |> Session.set_active_channel("#general")
        |> Session.remove_channel("#random")

      assert session.active_channel == "#general"
    end

    test "is a no-op when removing a channel not in the list" do
      session = Session.new("Rodrigo") |> Session.add_channel("#general")
      updated = Session.remove_channel(session, "#nonexistent")
      assert updated.channels == ["#general"]
    end
  end

  describe "set_identified/2" do
    test "sets identified to true" do
      session = Session.new("Rodrigo")
      updated = Session.set_identified(session, true)
      assert updated.identified == true
    end

    test "sets identified back to false" do
      session = Session.new("Rodrigo") |> Session.set_identified(true)
      updated = Session.set_identified(session, false)
      assert updated.identified == false
    end
  end

  describe "set_active_channel/2" do
    test "sets the active channel" do
      session = Session.new("Rodrigo") |> Session.add_channel("#general")
      updated = Session.set_active_channel(session, "#general")
      assert updated.active_channel == "#general"
    end

    test "sets active channel to nil" do
      session =
        Session.new("Rodrigo")
        |> Session.add_channel("#general")
        |> Session.set_active_channel("#general")
        |> Session.set_active_channel(nil)

      assert session.active_channel == nil
    end
  end

  describe "set_away/2" do
    test "sets the user as away with a message" do
      session = Session.new("Rodrigo")
      updated = Session.set_away(session, "Gone fishing")
      assert updated.away == true
      assert updated.away_message == "Gone fishing"
    end

    test "clears away status when given nil" do
      session =
        Session.new("Rodrigo")
        |> Session.set_away("Gone fishing")
        |> Session.set_away(nil)

      assert session.away == false
      assert session.away_message == nil
    end
  end

  describe "add_pm_conversation/2" do
    test "adds a PM conversation" do
      session = Session.new("Rodrigo") |> Session.add_pm_conversation("Alice")
      assert session.pm_conversations == ["Alice"]
    end

    test "does not add duplicate PM conversations" do
      session =
        Session.new("Rodrigo")
        |> Session.add_pm_conversation("Alice")
        |> Session.add_pm_conversation("Alice")

      assert session.pm_conversations == ["Alice"]
    end
  end

  describe "remove_pm_conversation/2" do
    test "removes a PM conversation" do
      session =
        Session.new("Rodrigo")
        |> Session.add_pm_conversation("Alice")
        |> Session.add_pm_conversation("Bob")
        |> Session.remove_pm_conversation("Alice")

      assert session.pm_conversations == ["Bob"]
    end

    test "resets active_pm when removing the active PM conversation" do
      session =
        Session.new("Rodrigo")
        |> Session.add_pm_conversation("Alice")
        |> Session.set_active_pm("Alice")
        |> Session.remove_pm_conversation("Alice")

      assert session.active_pm == nil
    end

    test "keeps active_pm when removing a different PM conversation" do
      session =
        Session.new("Rodrigo")
        |> Session.add_pm_conversation("Alice")
        |> Session.add_pm_conversation("Bob")
        |> Session.set_active_pm("Alice")
        |> Session.remove_pm_conversation("Bob")

      assert session.active_pm == "Alice"
    end
  end

  describe "set_active_pm/2" do
    test "sets the active PM and clears active_channel" do
      session =
        Session.new("Rodrigo")
        |> Session.add_channel("#general")
        |> Session.set_active_channel("#general")
        |> Session.set_active_pm("Alice")

      assert session.active_pm == "Alice"
      assert session.active_channel == nil
    end
  end

  describe "toggle_strip_formatting/1" do
    test "defaults to false" do
      session = Session.new("Rodrigo")
      assert session.strip_formatting == false
    end

    test "toggles from false to true" do
      session = Session.new("Rodrigo")
      updated = Session.toggle_strip_formatting(session)
      assert updated.strip_formatting == true
    end

    test "toggles from true back to false" do
      session =
        Session.new("Rodrigo")
        |> Session.toggle_strip_formatting()
        |> Session.toggle_strip_formatting()

      assert session.strip_formatting == false
    end

    test "preserves other fields" do
      session =
        Session.new("Rodrigo")
        |> Session.add_channel("#general")
        |> Session.set_identified(true)
        |> Session.toggle_strip_formatting()

      assert session.strip_formatting == true
      assert session.channels == ["#general"]
      assert session.identified == true
    end
  end

  describe "set_active_channel/2 clears active_pm" do
    test "setting active_channel clears active_pm" do
      session =
        Session.new("Rodrigo")
        |> Session.add_channel("#general")
        |> Session.set_active_pm("Alice")
        |> Session.set_active_channel("#general")

      assert session.active_channel == "#general"
      assert session.active_pm == nil
    end
  end

  describe "notify_list" do
    alias RetroHexChat.Presence.NotifyList

    test "new/1 initializes with empty notify_list" do
      session = Session.new("Rodrigo")
      expected = NotifyList.new()
      assert session.notify_list == expected
    end

    test "new/1 notify_list has empty entries and default settings" do
      session = Session.new("Rodrigo")
      assert session.notify_list.entries == []
      assert session.notify_list.settings == %{auto_whois: false}
    end

    test "set_notify_list/2 replaces the notify list" do
      session = Session.new("Rodrigo")
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Rodrigo", "Alice", "A buddy")
      list = NotifyList.set_auto_whois(list, true)

      updated = Session.set_notify_list(session, list)
      assert updated.notify_list == list
      assert length(updated.notify_list.entries) == 1
      assert updated.notify_list.settings.auto_whois == true
    end

    test "set_notify_list/2 preserves other session fields" do
      session =
        Session.new("Rodrigo")
        |> Session.add_channel("#general")
        |> Session.set_identified(true)

      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Rodrigo", "Bob", nil)

      updated = Session.set_notify_list(session, list)
      assert updated.channels == ["#general"]
      assert updated.identified == true
      assert updated.nickname == "Rodrigo"
    end

    test "get_notify_list/1 returns the current notify list" do
      session = Session.new("Rodrigo")
      assert Session.get_notify_list(session) == NotifyList.new()
    end

    test "get_notify_list/1 returns updated list after set" do
      session = Session.new("Rodrigo")
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Rodrigo", "Alice", "Friend")

      session = Session.set_notify_list(session, list)
      result = Session.get_notify_list(session)
      assert result == list
      assert length(result.entries) == 1
    end
  end

  describe "auto_join_on_invite" do
    test "defaults to false" do
      session = Session.new("Rodrigo")
      assert session.auto_join_on_invite == false
    end

    test "get_auto_join_on_invite/1 returns the current value" do
      session = Session.new("Rodrigo")
      assert Session.get_auto_join_on_invite(session) == false
    end

    test "set_auto_join_on_invite/2 sets to true" do
      session = Session.new("Rodrigo")
      updated = Session.set_auto_join_on_invite(session, true)
      assert updated.auto_join_on_invite == true
    end

    test "set_auto_join_on_invite/2 sets to false" do
      session =
        Session.new("Rodrigo")
        |> Session.set_auto_join_on_invite(true)
        |> Session.set_auto_join_on_invite(false)

      assert session.auto_join_on_invite == false
    end

    test "toggle_auto_join_on_invite/1 toggles from false to true" do
      session = Session.new("Rodrigo")
      updated = Session.toggle_auto_join_on_invite(session)
      assert updated.auto_join_on_invite == true
    end

    test "toggle_auto_join_on_invite/1 toggles from true back to false" do
      session =
        Session.new("Rodrigo")
        |> Session.toggle_auto_join_on_invite()
        |> Session.toggle_auto_join_on_invite()

      assert session.auto_join_on_invite == false
    end

    test "toggle preserves other fields" do
      session =
        Session.new("Rodrigo")
        |> Session.add_channel("#general")
        |> Session.set_identified(true)
        |> Session.toggle_auto_join_on_invite()

      assert session.auto_join_on_invite == true
      assert session.channels == ["#general"]
      assert session.identified == true
    end
  end

  describe "log_preferences" do
    alias RetroHexChat.Chat.DisplayPreferences

    test "new/1 initializes with default DisplayPreferences" do
      session = Session.new("Rodrigo")
      assert session.log_preferences == DisplayPreferences.new()
    end

    test "set_log_preferences/2 updates the preferences" do
      session = Session.new("Rodrigo")
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_joins)

      updated = Session.set_log_preferences(session, prefs)
      assert updated.log_preferences.show_joins == false
    end

    test "set_log_preferences/2 preserves other session fields" do
      session =
        Session.new("Rodrigo")
        |> Session.add_channel("#general")
        |> Session.set_identified(true)

      prefs =
        DisplayPreferences.new()
        |> DisplayPreferences.set_timestamp_format(:hh_mm)

      updated = Session.set_log_preferences(session, prefs)
      assert updated.channels == ["#general"]
      assert updated.identified == true
      assert updated.nickname == "Rodrigo"
    end

    test "log_preferences/1 returns the current preferences" do
      session = Session.new("Rodrigo")
      assert Session.log_preferences(session) == DisplayPreferences.new()
    end

    test "log_preferences/1 returns updated prefs after set" do
      session = Session.new("Rodrigo")

      prefs =
        DisplayPreferences.new()
        |> DisplayPreferences.toggle_event(:show_kicks)
        |> DisplayPreferences.set_timestamp_format(:dd_mm_hh_mm)

      session = Session.set_log_preferences(session, prefs)
      result = Session.log_preferences(session)
      assert result.show_kicks == false
      assert result.timestamp_format == :dd_mm_hh_mm
    end
  end

  describe "user_modes" do
    test "new/1 initializes with empty user_modes MapSet" do
      session = Session.new("Rodrigo")
      assert session.user_modes == MapSet.new()
    end

    test "has_mode?/2 returns false for unset mode" do
      session = Session.new("Rodrigo")
      refute Session.has_mode?(session, :wallops)
    end

    test "set_mode/2 enables a user mode" do
      session = Session.new("Rodrigo") |> Session.set_mode(:wallops)
      assert Session.has_mode?(session, :wallops)
    end

    test "unset_mode/2 disables a user mode" do
      session =
        Session.new("Rodrigo")
        |> Session.set_mode(:wallops)
        |> Session.unset_mode(:wallops)

      refute Session.has_mode?(session, :wallops)
    end

    test "set_mode/2 is idempotent" do
      session =
        Session.new("Rodrigo")
        |> Session.set_mode(:wallops)
        |> Session.set_mode(:wallops)

      assert Session.has_mode?(session, :wallops)
      assert MapSet.size(session.user_modes) == 1
    end

    test "unset_mode/2 on unset mode is noop" do
      session = Session.new("Rodrigo") |> Session.unset_mode(:wallops)
      refute Session.has_mode?(session, :wallops)
    end
  end

  describe "welcomed_channels" do
    test "new/1 initializes with empty welcomed_channels MapSet" do
      session = Session.new("Rodrigo")
      assert session.welcomed_channels == MapSet.new()
    end

    test "welcomed_channel?/2 returns false for unwelcomed channel" do
      session = Session.new("Rodrigo")
      refute Session.welcomed_channel?(session, "#test")
    end

    test "add_welcomed_channel/2 marks a channel as welcomed" do
      session = Session.new("Rodrigo") |> Session.add_welcomed_channel("#test")
      assert Session.welcomed_channel?(session, "#test")
    end

    test "add_welcomed_channel/2 is idempotent" do
      session =
        Session.new("Rodrigo")
        |> Session.add_welcomed_channel("#test")
        |> Session.add_welcomed_channel("#test")

      assert Session.welcomed_channel?(session, "#test")
      assert MapSet.size(session.welcomed_channels) == 1
    end

    test "add_welcomed_channel/2 preserves other channels" do
      session =
        Session.new("Rodrigo")
        |> Session.add_welcomed_channel("#one")
        |> Session.add_welcomed_channel("#two")

      assert Session.welcomed_channel?(session, "#one")
      assert Session.welcomed_channel?(session, "#two")
    end
  end

  describe "notice_routing" do
    test "default routing is :active" do
      session = Session.new("Rodrigo")
      assert session.notice_routing == :active
    end

    test "get_notice_routing/1 returns current routing" do
      session = Session.new("Rodrigo")
      assert Session.get_notice_routing(session) == :active
    end

    test "set_notice_routing/2 updates routing to :status" do
      session = Session.new("Rodrigo")
      updated = Session.set_notice_routing(session, :status)
      assert updated.notice_routing == :status
      assert Session.get_notice_routing(updated) == :status
    end

    test "set_notice_routing/2 updates routing to :sender" do
      session = Session.new("Rodrigo")
      updated = Session.set_notice_routing(session, :sender)
      assert updated.notice_routing == :sender
    end

    test "set_notice_routing/2 preserves other fields" do
      session =
        Session.new("Rodrigo")
        |> Session.add_channel("#general")
        |> Session.set_identified(true)

      updated = Session.set_notice_routing(session, :status)
      assert updated.channels == ["#general"]
      assert updated.identified == true
      assert updated.nickname == "Rodrigo"
    end
  end
end
