defmodule RetroHexChat.Chat.NotificationRouterTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.NotificationPreferences
  alias RetroHexChat.Chat.NotificationRouter

  @moduletag :unit

  defp default_prefs, do: NotificationPreferences.new()

  describe "should_notify?/4 — active channel suppression" do
    test "skips notification when channel is active" do
      result =
        NotificationRouter.should_notify?(
          :channel_message,
          "#general",
          default_prefs(),
          "#general"
        )

      assert result == :skip
    end

    test "notifies when channel is not active and trigger enabled" do
      prefs = NotificationPreferences.set_trigger_channel_messages(default_prefs(), true)
      result = NotificationRouter.should_notify?(:channel_message, "#dev", prefs, "#general")

      assert {:notify, _} = result
    end

    test "PM always notifies even if active PM differs" do
      prefs = default_prefs()
      result = NotificationRouter.should_notify?(:pm, nil, prefs, "#general")

      assert {:notify, :pm} = result
    end
  end

  describe "should_notify?/4 — DND mode" do
    test "returns :dnd_silent when DND is enabled" do
      prefs = NotificationPreferences.set_dnd_enabled(default_prefs(), true)
      result = NotificationRouter.should_notify?(:mention, "#dev", prefs, "#general")

      assert result == :dnd_silent
    end

    test "DND still allows badge updates (returned as :dnd_silent, not :skip)" do
      prefs = NotificationPreferences.set_dnd_enabled(default_prefs(), true)
      result = NotificationRouter.should_notify?(:mention, "#dev", prefs, "#general")

      assert result == :dnd_silent
    end
  end

  describe "should_notify?/4 — muted channel" do
    test "skips notification for muted channel" do
      prefs =
        default_prefs()
        |> NotificationPreferences.set_channel_level("#music", :mute)

      result = NotificationRouter.should_notify?(:channel_message, "#music", prefs, "#general")

      assert result == :skip
    end
  end

  describe "should_notify?/4 — mentions_only channel" do
    test "skips non-highlighted message in mentions_only channel" do
      prefs =
        default_prefs()
        |> NotificationPreferences.set_channel_level("#general", :mentions_only)

      result =
        NotificationRouter.should_notify?(
          :channel_message,
          "#general",
          prefs,
          "#dev"
        )

      assert result == :skip
    end

    test "notifies for highlighted message in mentions_only channel" do
      prefs =
        default_prefs()
        |> NotificationPreferences.set_channel_level("#general", :mentions_only)

      result =
        NotificationRouter.should_notify?(
          :mention,
          "#general",
          prefs,
          "#dev"
        )

      assert {:notify, :mention} = result
    end
  end

  describe "should_notify?/4 — trigger rules" do
    test "skips mention when trigger_mentions is disabled" do
      prefs = NotificationPreferences.set_trigger_mentions(default_prefs(), false)
      result = NotificationRouter.should_notify?(:mention, "#dev", prefs, "#general")

      assert result == :skip
    end

    test "skips PM when trigger_pms is disabled" do
      prefs = NotificationPreferences.set_trigger_pms(default_prefs(), false)
      result = NotificationRouter.should_notify?(:pm, nil, prefs, "#general")

      assert result == :skip
    end

    test "skips channel message when trigger_channel_messages is disabled (default)" do
      result =
        NotificationRouter.should_notify?(:channel_message, "#dev", default_prefs(), "#general")

      assert result == :skip
    end

    test "notifies for channel message when trigger_channel_messages is enabled" do
      prefs = NotificationPreferences.set_trigger_channel_messages(default_prefs(), true)
      result = NotificationRouter.should_notify?(:channel_message, "#dev", prefs, "#general")

      assert {:notify, :channel_message} = result
    end

    test "skips join when trigger_joins_leaves is disabled (default)" do
      result = NotificationRouter.should_notify?(:join, "#dev", default_prefs(), "#general")

      assert result == :skip
    end

    test "notifies for join when trigger_joins_leaves is enabled" do
      prefs = NotificationPreferences.set_trigger_joins_leaves(default_prefs(), true)
      result = NotificationRouter.should_notify?(:join, "#dev", prefs, "#general")

      assert {:notify, :join} = result
    end

    test "notifies for leave when trigger_joins_leaves is enabled" do
      prefs = NotificationPreferences.set_trigger_joins_leaves(default_prefs(), true)
      result = NotificationRouter.should_notify?(:leave, "#dev", prefs, "#general")

      assert {:notify, :leave} = result
    end
  end

  describe "should_notify?/4 — default behavior for mentions and PMs" do
    test "mention triggers notification by default" do
      result = NotificationRouter.should_notify?(:mention, "#dev", default_prefs(), "#general")

      assert {:notify, :mention} = result
    end

    test "PM triggers notification by default" do
      result = NotificationRouter.should_notify?(:pm, nil, default_prefs(), "#general")

      assert {:notify, :pm} = result
    end
  end

  describe "notification_type/1" do
    test "returns correct type for each event" do
      assert NotificationRouter.notification_type(:mention) == :mention
      assert NotificationRouter.notification_type(:pm) == :pm
      assert NotificationRouter.notification_type(:channel_message) == :channel_message
      assert NotificationRouter.notification_type(:join) == :join
      assert NotificationRouter.notification_type(:leave) == :leave
    end
  end

  describe "creates_center_entry?/1" do
    test "mentions create notification center entries" do
      assert NotificationRouter.creates_center_entry?(:mention) == true
    end

    test "PMs create notification center entries" do
      assert NotificationRouter.creates_center_entry?(:pm) == true
    end

    test "channel messages create notification center entries" do
      assert NotificationRouter.creates_center_entry?(:channel_message) == true
    end

    test "joins do not create notification center entries" do
      assert NotificationRouter.creates_center_entry?(:join) == false
    end

    test "leaves do not create notification center entries" do
      assert NotificationRouter.creates_center_entry?(:leave) == false
    end
  end
end
