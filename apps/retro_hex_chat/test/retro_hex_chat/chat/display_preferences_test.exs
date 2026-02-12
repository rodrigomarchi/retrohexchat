defmodule RetroHexChat.Chat.DisplayPreferencesTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.DisplayPreferences

  # Fixed DateTime for deterministic timestamp tests
  @test_datetime ~U[2026-02-11 14:05:09Z]

  describe "new/0" do
    test "returns struct with all event types visible" do
      prefs = DisplayPreferences.new()

      assert prefs.show_joins == true
      assert prefs.show_parts == true
      assert prefs.show_kicks == true
      assert prefs.show_mode_changes == true
      assert prefs.show_topic_changes == true
    end

    test "returns struct with default timestamp format :hh_mm_ss" do
      prefs = DisplayPreferences.new()

      assert prefs.timestamp_format == :hh_mm_ss
    end

    test "returns a %DisplayPreferences{} struct" do
      prefs = DisplayPreferences.new()

      assert %DisplayPreferences{} = prefs
    end
  end

  describe "toggle_event/2" do
    test "toggles show_joins from true to false" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_joins)

      assert prefs.show_joins == false
    end

    test "toggles show_joins from false back to true" do
      prefs =
        DisplayPreferences.new()
        |> DisplayPreferences.toggle_event(:show_joins)
        |> DisplayPreferences.toggle_event(:show_joins)

      assert prefs.show_joins == true
    end

    test "toggles show_parts" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_parts)

      assert prefs.show_parts == false
    end

    test "toggles show_kicks" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_kicks)

      assert prefs.show_kicks == false
    end

    test "toggles show_mode_changes" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_mode_changes)

      assert prefs.show_mode_changes == false
    end

    test "toggles show_topic_changes" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_topic_changes)

      assert prefs.show_topic_changes == false
    end

    test "does not affect other fields when toggling one" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_joins)

      assert prefs.show_joins == false
      assert prefs.show_parts == true
      assert prefs.show_kicks == true
      assert prefs.show_mode_changes == true
      assert prefs.show_topic_changes == true
      assert prefs.timestamp_format == :hh_mm_ss
    end

    test "raises FunctionClauseError for invalid field" do
      assert_raise FunctionClauseError, fn ->
        DisplayPreferences.new() |> DisplayPreferences.toggle_event(:invalid_field)
      end
    end
  end

  describe "set_timestamp_format/2" do
    test "sets format to :hh_mm" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.set_timestamp_format(:hh_mm)

      assert prefs.timestamp_format == :hh_mm
    end

    test "sets format to :hh_mm_ss" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.set_timestamp_format(:hh_mm_ss)

      assert prefs.timestamp_format == :hh_mm_ss
    end

    test "sets format to :dd_mm_hh_mm" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.set_timestamp_format(:dd_mm_hh_mm)

      assert prefs.timestamp_format == :dd_mm_hh_mm
    end

    test "does not affect other fields" do
      prefs =
        DisplayPreferences.new()
        |> DisplayPreferences.toggle_event(:show_joins)
        |> DisplayPreferences.set_timestamp_format(:hh_mm)

      assert prefs.timestamp_format == :hh_mm
      assert prefs.show_joins == false
    end

    test "raises FunctionClauseError for invalid format" do
      assert_raise FunctionClauseError, fn ->
        DisplayPreferences.new() |> DisplayPreferences.set_timestamp_format(:invalid)
      end
    end
  end

  describe "format_timestamp/2" do
    test "formats as [HH:MM] for :hh_mm" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.set_timestamp_format(:hh_mm)

      assert DisplayPreferences.format_timestamp(prefs, @test_datetime) == "[14:05]"
    end

    test "formats as [HH:MM:SS] for :hh_mm_ss" do
      prefs = DisplayPreferences.new()

      assert DisplayPreferences.format_timestamp(prefs, @test_datetime) == "[14:05:09]"
    end

    test "formats as [DD/MM HH:MM] for :dd_mm_hh_mm" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.set_timestamp_format(:dd_mm_hh_mm)

      assert DisplayPreferences.format_timestamp(prefs, @test_datetime) == "[11/02 14:05]"
    end

    test "zero-pads single-digit hours" do
      dt = ~U[2026-01-05 03:07:02Z]
      prefs = DisplayPreferences.new()

      assert DisplayPreferences.format_timestamp(prefs, dt) == "[03:07:02]"
    end

    test "zero-pads single-digit day and month in dd_mm_hh_mm" do
      dt = ~U[2026-01-05 03:07:02Z]

      prefs = DisplayPreferences.new() |> DisplayPreferences.set_timestamp_format(:dd_mm_hh_mm)

      assert DisplayPreferences.format_timestamp(prefs, dt) == "[05/01 03:07]"
    end

    test "handles midnight correctly" do
      dt = ~U[2026-01-01 00:00:00Z]
      prefs = DisplayPreferences.new()

      assert DisplayPreferences.format_timestamp(prefs, dt) == "[00:00:00]"
    end

    test "handles end of day correctly" do
      dt = ~U[2026-12-31 23:59:59Z]
      prefs = DisplayPreferences.new()

      assert DisplayPreferences.format_timestamp(prefs, dt) == "[23:59:59]"
    end

    test "double-digit values are not double-padded" do
      dt = ~U[2026-12-25 13:45:30Z]

      prefs = DisplayPreferences.new() |> DisplayPreferences.set_timestamp_format(:dd_mm_hh_mm)

      assert DisplayPreferences.format_timestamp(prefs, dt) == "[25/12 13:45]"
    end
  end

  describe "visible_type?/2 for always-visible types" do
    test "message type is always visible" do
      prefs = DisplayPreferences.new()

      assert DisplayPreferences.visible_type?(prefs, "message")
    end

    test "action type is always visible" do
      prefs = DisplayPreferences.new()

      assert DisplayPreferences.visible_type?(prefs, "action")
    end

    test "message type visible even with all toggles off" do
      prefs =
        DisplayPreferences.new()
        |> DisplayPreferences.toggle_event(:show_joins)
        |> DisplayPreferences.toggle_event(:show_parts)
        |> DisplayPreferences.toggle_event(:show_kicks)
        |> DisplayPreferences.toggle_event(:show_mode_changes)
        |> DisplayPreferences.toggle_event(:show_topic_changes)

      assert DisplayPreferences.visible_type?(prefs, "message")
    end

    test "action type visible even with all toggles off" do
      prefs =
        DisplayPreferences.new()
        |> DisplayPreferences.toggle_event(:show_joins)
        |> DisplayPreferences.toggle_event(:show_parts)
        |> DisplayPreferences.toggle_event(:show_kicks)
        |> DisplayPreferences.toggle_event(:show_mode_changes)
        |> DisplayPreferences.toggle_event(:show_topic_changes)

      assert DisplayPreferences.visible_type?(prefs, "action")
    end

    test "unknown type is always visible" do
      prefs = DisplayPreferences.new()

      assert DisplayPreferences.visible_type?(prefs, "unknown_type")
    end
  end

  describe "visible_type?/3 for system join messages" do
    test "visible when show_joins is true" do
      prefs = DisplayPreferences.new()

      assert DisplayPreferences.visible_type?(prefs, "system", "User joined #lobby")
    end

    test "hidden when show_joins is false and content contains 'joined'" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_joins)

      refute DisplayPreferences.visible_type?(prefs, "system", "User joined #lobby")
    end

    test "hidden when show_joins is false and content contains 'has joined'" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_joins)

      refute DisplayPreferences.visible_type?(prefs, "system", "User has joined the channel")
    end

    test "case-insensitive matching for join content" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_joins)

      refute DisplayPreferences.visible_type?(prefs, "system", "User JOINED #lobby")
    end
  end

  describe "visible_type?/3 for system part messages" do
    test "visible when show_parts is true" do
      prefs = DisplayPreferences.new()

      assert DisplayPreferences.visible_type?(prefs, "system", "User left #lobby")
    end

    test "hidden when show_parts is false and content contains 'left'" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_parts)

      refute DisplayPreferences.visible_type?(prefs, "system", "User left #lobby")
    end

    test "hidden when show_parts is false and content contains 'has left'" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_parts)

      refute DisplayPreferences.visible_type?(prefs, "system", "User has left the channel")
    end

    test "hidden when show_parts is false and content contains 'parted'" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_parts)

      refute DisplayPreferences.visible_type?(prefs, "system", "User parted #lobby")
    end

    test "case-insensitive matching for part content" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_parts)

      refute DisplayPreferences.visible_type?(prefs, "system", "User LEFT the channel")
    end
  end

  describe "visible_type?/3 for system kick messages" do
    test "visible when show_kicks is true" do
      prefs = DisplayPreferences.new()

      assert DisplayPreferences.visible_type?(prefs, "system", "User was kicked from #lobby")
    end

    test "hidden when show_kicks is false and content contains 'kicked'" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_kicks)

      refute DisplayPreferences.visible_type?(prefs, "system", "Admin kicked User from #lobby")
    end

    test "hidden when show_kicks is false and content contains 'was kicked'" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_kicks)

      refute DisplayPreferences.visible_type?(prefs, "system", "User was kicked by Admin")
    end

    test "case-insensitive matching for kick content" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_kicks)

      refute DisplayPreferences.visible_type?(prefs, "system", "User KICKED out")
    end
  end

  describe "visible_type?/3 for system mode messages" do
    test "visible when show_mode_changes is true" do
      prefs = DisplayPreferences.new()

      assert DisplayPreferences.visible_type?(prefs, "system", "Admin sets mode +o User")
    end

    test "hidden when show_mode_changes is false and content contains 'sets mode'" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_mode_changes)

      refute DisplayPreferences.visible_type?(prefs, "system", "Admin sets mode +o User")
    end

    test "hidden when show_mode_changes is false and content contains 'mode'" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_mode_changes)

      refute DisplayPreferences.visible_type?(prefs, "system", "Channel mode changed to +i")
    end

    test "case-insensitive matching for mode content" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_mode_changes)

      refute DisplayPreferences.visible_type?(prefs, "system", "Admin SETS MODE +v User")
    end
  end

  describe "visible_type?/3 for system topic messages" do
    test "visible when show_topic_changes is true" do
      prefs = DisplayPreferences.new()

      assert DisplayPreferences.visible_type?(
               prefs,
               "system",
               "Admin changed the topic to: Hello"
             )
    end

    test "hidden when show_topic_changes is false and content contains 'topic'" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_topic_changes)

      refute DisplayPreferences.visible_type?(prefs, "system", "Channel topic is now: Hello")
    end

    test "hidden when show_topic_changes is false and content contains 'changed the topic'" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_topic_changes)

      refute DisplayPreferences.visible_type?(
               prefs,
               "system",
               "Admin changed the topic to: Welcome"
             )
    end

    test "case-insensitive matching for topic content" do
      prefs = DisplayPreferences.new() |> DisplayPreferences.toggle_event(:show_topic_changes)

      refute DisplayPreferences.visible_type?(prefs, "system", "TOPIC changed by Admin")
    end
  end

  describe "visible_type?/3 for other system messages" do
    test "unrecognized system content is always visible" do
      prefs =
        DisplayPreferences.new()
        |> DisplayPreferences.toggle_event(:show_joins)
        |> DisplayPreferences.toggle_event(:show_parts)
        |> DisplayPreferences.toggle_event(:show_kicks)
        |> DisplayPreferences.toggle_event(:show_mode_changes)
        |> DisplayPreferences.toggle_event(:show_topic_changes)

      assert DisplayPreferences.visible_type?(
               prefs,
               "system",
               "Server notice: maintenance at 3am"
             )
    end

    test "system message with empty content is always visible" do
      prefs =
        DisplayPreferences.new()
        |> DisplayPreferences.toggle_event(:show_joins)

      assert DisplayPreferences.visible_type?(prefs, "system", "")
    end

    test "system message with no content arg defaults to visible" do
      prefs =
        DisplayPreferences.new()
        |> DisplayPreferences.toggle_event(:show_joins)

      assert DisplayPreferences.visible_type?(prefs, "system")
    end
  end
end
