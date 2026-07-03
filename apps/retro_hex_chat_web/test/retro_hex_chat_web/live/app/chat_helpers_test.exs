defmodule RetroHexChatWeb.App.ChatHelpersTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChatWeb.App.ChatHelpers

  @dt ~U[2026-01-07 11:37:05Z]

  describe "format_time/3" do
    # The two-line meta column frames the timestamp itself, so format_time is
    # bracket-free (no [ ]) across every format.
    test "hh_mm renders bare HH:MM" do
      assert ChatHelpers.format_time(@dt, :hh_mm, "Etc/UTC") == "11:37"
    end

    test "hh_mm_ss renders bare HH:MM:SS" do
      assert ChatHelpers.format_time(@dt, :hh_mm_ss, "Etc/UTC") == "11:37:05"
    end

    test "dd_mm_hh_mm renders bare DD/MM HH:MM (the default line format)" do
      assert ChatHelpers.format_time(@dt, :dd_mm_hh_mm, "Etc/UTC") == "07/01 11:37"
    end

    test "none renders empty string" do
      assert ChatHelpers.format_time(@dt, :none, "Etc/UTC") == ""
    end

    test "unknown format falls back to HH:MM" do
      assert ChatHelpers.format_time(@dt, :whatever, "Etc/UTC") == "11:37"
    end

    test "shifts to the given timezone" do
      # America/Sao_Paulo is UTC-3 → 11:37 UTC becomes 08:37 local.
      assert ChatHelpers.format_time(@dt, :hh_mm, "America/Sao_Paulo") == "08:37"
    end

    test "non-datetime input renders a placeholder, never crashes" do
      assert ChatHelpers.format_time(nil, :hh_mm, "Etc/UTC") == "--:--"
      assert ChatHelpers.format_time("bogus", :dd_mm_hh_mm, "Etc/UTC") == "--:--"
    end
  end

  describe "format_duration/1" do
    test "formats sub-hour durations as MMm SSs" do
      assert ChatHelpers.format_duration(522) == "08m 42s"
      assert ChatHelpers.format_duration(0) == "00m 00s"
    end

    test "formats hour-plus durations as HHh MMm" do
      assert ChatHelpers.format_duration(3720) == "1h 02m"
    end

    test "returns nil for a missing/invalid value" do
      assert ChatHelpers.format_duration(nil) == nil
      assert ChatHelpers.format_duration(-5) == nil
    end
  end

  describe "linkify_channels/1" do
    test "wraps a channel name in a chat-channel-link span" do
      html = ChatHelpers.linkify_channels("join #general now")
      assert html =~ ~s(<span class="chat-channel-link" data-channel="#general">#general</span>)
    end

    test "wraps multiple channels" do
      html = ChatHelpers.linkify_channels("#alpha and #beta")
      assert html =~ ~s(data-channel="#alpha")
      assert html =~ ~s(data-channel="#beta")
    end

    test "does not rewrite channel-like text inside existing tags" do
      html = ChatHelpers.linkify_channels(~s(<a href="/#nope">x</a> #real))
      # The href attribute is left untouched; only the bare #real is linkified.
      assert html =~ ~s(<a href="/#nope">)
      assert html =~ ~s(data-channel="#real")
      refute html =~ ~s(data-channel="/#nope")
    end

    test "leaves plain text without channels unchanged" do
      assert ChatHelpers.linkify_channels("no channels here") == "no channels here"
    end
  end

  describe "format_content/2" do
    test "linkifies channels in message content" do
      assert ChatHelpers.format_content("see #general", false) =~ ~s(data-channel="#general")
    end

    test "strips mIRC formatting when strip is true" do
      # \x02 is the bold control code; stripped output must not contain it.
      refute ChatHelpers.format_content("\x02bold\x02 text", true) =~ "\x02"
      assert ChatHelpers.format_content("\x02bold\x02 text", true) =~ "bold"
    end

    test "escapes HTML in content (no raw injection)" do
      refute ChatHelpers.format_content("<script>alert(1)</script>", false) =~ "<script>"
    end
  end

  describe "default_nick_color/1" do
    test "is deterministic for a given nick" do
      assert ChatHelpers.default_nick_color("alice") == ChatHelpers.default_nick_color("alice")
    end

    test "returns a nick-color-N class within the palette range" do
      for nick <- ~w(alice bob carol dave eve mallory) do
        assert ChatHelpers.default_nick_color(nick) =~ ~r/^nick-color-([0-9]|1[01])$/
      end
    end
  end
end
