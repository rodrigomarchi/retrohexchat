defmodule RetroHexChat.Commands.Handlers.IgnoreTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Ignore

  @context %{
    nickname: "Tester",
    active_channel: "#test",
    channels: ["#test"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "accepts empty string (bare /ignore)" do
      assert :ok = Ignore.validate("")
    end

    test "accepts nickname only" do
      assert :ok = Ignore.validate("SpamBot")
    end

    test "accepts nickname with type" do
      assert :ok = Ignore.validate("SpamBot pms")
    end

    test "accepts nickname with type and duration" do
      assert :ok = Ignore.validate("SpamBot all 5m")
    end
  end

  describe "execute/2" do
    test "bare /ignore returns ignore_list ui_action" do
      assert {:ok, :ui_action, :ignore_list, %{}} = Ignore.execute([], @context)
    end

    test "with nickname returns ignore_add with type :all and nil duration" do
      assert {:ok, :ui_action, :ignore_add, %{nickname: "SpamBot", type: :all, duration: nil}} =
               Ignore.execute(["SpamBot"], @context)
    end

    test "self-ignore returns error" do
      assert {:error, "You cannot ignore yourself"} =
               Ignore.execute(["Tester"], @context)
    end

    test "self-ignore is case-insensitive" do
      assert {:error, "You cannot ignore yourself"} =
               Ignore.execute(["tester"], @context)
    end
  end

  # ── US2: Type parameter ────────────────────────────────

  describe "execute/2 with type parameter (US2)" do
    test "with nickname and type returns correct type atom" do
      assert {:ok, :ui_action, :ignore_add, %{nickname: "SpamBot", type: :pms, duration: nil}} =
               Ignore.execute(["SpamBot", "pms"], @context)
    end

    test "with all valid types" do
      for type_str <- ~w(all messages pms invites actions) do
        expected_type = String.to_atom(type_str)

        assert {:ok, :ui_action, :ignore_add, %{nickname: "User", type: ^expected_type}} =
                 Ignore.execute(["User", type_str], @context)
      end
    end

    test "rejects invalid type" do
      assert {:error, msg} = Ignore.execute(["User", "invalid"], @context)
      assert msg =~ "Invalid ignore type"
      assert msg =~ "valid"
    end
  end

  # ── US3: Duration parameter ──────────────────────────────

  describe "execute/2 with duration parameter (US3)" do
    test "5m parses to 300 seconds" do
      assert {:ok, :ui_action, :ignore_add, %{nickname: "User", type: :all, duration: 300}} =
               Ignore.execute(["User", "all", "5m"], @context)
    end

    test "2h parses to 7200 seconds" do
      assert {:ok, :ui_action, :ignore_add, %{nickname: "User", type: :all, duration: 7200}} =
               Ignore.execute(["User", "all", "2h"], @context)
    end

    test "1d parses to 86400 seconds" do
      assert {:ok, :ui_action, :ignore_add, %{nickname: "User", type: :all, duration: 86_400}} =
               Ignore.execute(["User", "all", "1d"], @context)
    end

    test "0m returns error" do
      assert {:error, msg} = Ignore.execute(["User", "all", "0m"], @context)
      assert msg =~ "positive"
    end

    test "invalid format returns error" do
      assert {:error, msg} = Ignore.execute(["User", "all", "xyz"], @context)
      assert msg =~ "Invalid duration"
    end

    test "negative duration format returns error" do
      assert {:error, msg} = Ignore.execute(["User", "all", "-5m"], @context)
      assert msg =~ "Invalid duration"
    end
  end

  describe "help/0" do
    test "returns help map with correct name" do
      help = Ignore.help()
      assert help.name == "ignore"
    end

    test "returns help map with syntax string" do
      help = Ignore.help()
      assert is_binary(help.syntax)
      assert help.syntax =~ "/ignore"
    end

    test "returns help map with examples list" do
      help = Ignore.help()
      assert [_ | _] = help.examples
    end
  end
end
