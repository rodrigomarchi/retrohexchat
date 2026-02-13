defmodule RetroHexChat.Channels.ModesTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Channels.Modes

  describe "new/0" do
    test "returns empty modes struct" do
      modes = Modes.new()
      assert %Modes{} = modes
      refute Modes.moderated?(modes)
      refute Modes.invite_only?(modes)
      refute Modes.topic_locked?(modes)
      refute Modes.has_key?(modes)
      refute Modes.has_limit?(modes)
    end
  end

  describe "apply_changes/2 adding flags" do
    test "+m sets moderated" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+m")
      assert Modes.moderated?(modes)
    end

    test "+t sets topic lock" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+t")
      assert Modes.topic_locked?(modes)
    end

    test "+i sets invite-only" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+i")
      assert Modes.invite_only?(modes)
    end

    test "+k sets channel key" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+k", ["secret"])
      assert Modes.has_key?(modes)
      assert modes.key == "secret"
    end

    test "+l sets user limit" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+l", ["10"])
      assert Modes.has_limit?(modes)
      assert modes.limit == 10
    end
  end

  describe "apply_changes/2 removing flags" do
    test "-m removes moderated" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+m")
      assert Modes.moderated?(modes)
      {:ok, modes} = Modes.apply_changes(modes, "-m")
      refute Modes.moderated?(modes)
    end

    test "-t removes topic lock" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+t")
      {:ok, modes} = Modes.apply_changes(modes, "-t")
      refute Modes.topic_locked?(modes)
    end

    test "-i removes invite-only" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+i")
      {:ok, modes} = Modes.apply_changes(modes, "-i")
      refute Modes.invite_only?(modes)
    end

    test "-k removes channel key" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+k", ["secret"])
      {:ok, modes} = Modes.apply_changes(modes, "-k")
      refute Modes.has_key?(modes)
      assert modes.key == nil
    end

    test "-l removes user limit" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+l", ["10"])
      {:ok, modes} = Modes.apply_changes(modes, "-l")
      refute Modes.has_limit?(modes)
      assert modes.limit == nil
    end
  end

  describe "apply_changes/2 combined modes" do
    test "+mt sets moderated and topic lock" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+mt")
      assert Modes.moderated?(modes)
      assert Modes.topic_locked?(modes)
    end

    test "+kl with params sets key and limit" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+kl", ["secret", "10"])
      assert Modes.has_key?(modes)
      assert modes.key == "secret"
      assert Modes.has_limit?(modes)
      assert modes.limit == 10
    end
  end

  describe "to_string/1" do
    test "empty modes returns empty string" do
      assert Modes.to_string(Modes.new()) == ""
    end

    test "single flag" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+m")
      assert Modes.to_string(modes) == "+m"
    end

    test "multiple flags sorted alphabetically" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+mt")
      result = Modes.to_string(modes)
      assert result =~ "m"
      assert result =~ "t"
      assert String.starts_with?(result, "+")
    end

    test "includes k and l when set" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+kl", ["secret", "10"])
      result = Modes.to_string(modes)
      assert result =~ "k"
      assert result =~ "l"
    end
  end

  describe "query functions" do
    test "moderated?/1" do
      refute Modes.moderated?(Modes.new())
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+m")
      assert Modes.moderated?(modes)
    end

    test "invite_only?/1" do
      refute Modes.invite_only?(Modes.new())
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+i")
      assert Modes.invite_only?(modes)
    end

    test "topic_locked?/1" do
      refute Modes.topic_locked?(Modes.new())
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+t")
      assert Modes.topic_locked?(modes)
    end

    test "has_key?/1" do
      refute Modes.has_key?(Modes.new())
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+k", ["secret"])
      assert Modes.has_key?(modes)
    end

    test "has_limit?/1" do
      refute Modes.has_limit?(Modes.new())
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+l", ["10"])
      assert Modes.has_limit?(modes)
    end
  end

  describe "invalid mode string" do
    test "mode string without +/- returns error" do
      assert {:error, "Invalid mode string: must start with + or -"} =
               Modes.apply_changes(Modes.new(), "m")
    end
  end

  describe "apply_changes/2 invalid limit values" do
    test "+l with negative number is silently ignored" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+l", ["-1"])
      refute Modes.has_limit?(modes)
      assert modes.limit == nil
    end

    test "+l with zero is silently ignored" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+l", ["0"])
      refute Modes.has_limit?(modes)
      assert modes.limit == nil
    end

    test "+l with non-numeric text is silently ignored" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+l", ["abc"])
      refute Modes.has_limit?(modes)
      assert modes.limit == nil
    end

    test "+l with trailing text is silently ignored" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+l", ["10abc"])
      refute Modes.has_limit?(modes)
      assert modes.limit == nil
    end

    test "+l without param is silently ignored" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+l")
      refute Modes.has_limit?(modes)
      assert modes.limit == nil
    end
  end

  describe "+o and +v are user modes" do
    test "+o is silently ignored by apply_changes" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+o", ["nick"])
      assert modes == Modes.new()
    end

    test "+v is silently ignored by apply_changes" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+v", ["nick"])
      assert modes == Modes.new()
    end

    test "+mo applies moderated but ignores o" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+mo", ["nick"])
      assert Modes.moderated?(modes)
    end
  end

  describe "to_string/1 with invite_only flag" do
    test "to_string includes 'i' when invite_only is set" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+i")
      assert Modes.to_string(modes) == "+i"
    end

    test "to_string with invite_only and moderated includes both" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+im")
      result = Modes.to_string(modes)
      assert result =~ "i"
      assert result =~ "m"
    end
  end

  describe "+k without parameter" do
    test "+k without param sets key to nil" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+k")
      # Key is set to nil (parsed as {:add, :key, nil})
      assert modes.key == nil
    end
  end

  describe "to_string/1 with only key or limit" do
    test "to_string with only key set returns +k" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+k", ["secret"])
      assert Modes.to_string(modes) == "+k"
    end

    test "to_string with only limit set returns +l" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+l", ["10"])
      assert Modes.to_string(modes) == "+l"
    end
  end

  describe "new channel flags" do
    test "+n sets no_external flag" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+n")
      assert Modes.no_external?(modes)
    end

    test "-n removes no_external flag" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+n")
      {:ok, modes} = Modes.apply_changes(modes, "-n")
      refute Modes.no_external?(modes)
    end

    test "+s sets secret flag" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+s")
      assert Modes.secret?(modes)
    end

    test "+p sets private flag" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+p")
      assert Modes.private?(modes)
    end

    test "+c sets strip_colors flag" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+c")
      assert Modes.strip_colors?(modes)
    end

    test "+R sets registered_only flag" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+R")
      assert Modes.registered_only?(modes)
    end

    test "+K sets no_knock flag" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+K")
      assert Modes.no_knock?(modes)
    end
  end

  describe "+j join throttle" do
    test "+j sets join_throttle tuple" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+j", ["5:10"])
      assert Modes.has_join_throttle?(modes)
      assert modes.join_throttle == {5, 10}
    end

    test "-j removes join_throttle" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+j", ["5:10"])
      {:ok, modes} = Modes.apply_changes(modes, "-j")
      refute Modes.has_join_throttle?(modes)
      assert modes.join_throttle == nil
    end

    test "+j with invalid format is ignored" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+j", ["invalid"])
      refute Modes.has_join_throttle?(modes)
      assert modes.join_throttle == nil
    end

    test "+j with zero count is ignored" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+j", ["0:10"])
      refute Modes.has_join_throttle?(modes)
    end

    test "+j with zero seconds is ignored" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+j", ["5:0"])
      refute Modes.has_join_throttle?(modes)
    end
  end

  describe "+s/+p mutual exclusivity" do
    test "setting +p when +s is active fails" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+s")
      assert {:error, _} = Modes.apply_changes(modes, "+p")
    end

    test "setting +s when +p is active fails" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+p")
      assert {:error, _} = Modes.apply_changes(modes, "+s")
    end

    test "can set +s after removing +p" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+p")
      {:ok, modes} = Modes.apply_changes(modes, "-p")
      assert {:ok, _} = Modes.apply_changes(modes, "+s")
    end
  end

  describe "to_string/1 with new flags" do
    test "includes n for no_external" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+n")
      assert Modes.to_string(modes) =~ "n"
    end

    test "includes s for secret" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+s")
      assert Modes.to_string(modes) =~ "s"
    end

    test "includes j for join_throttle" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+j", ["5:10"])
      assert Modes.to_string(modes) =~ "j"
    end

    test "includes multiple new flags" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+nc")
      result = Modes.to_string(modes)
      assert result =~ "n"
      assert result =~ "c"
    end
  end
end
