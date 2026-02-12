defmodule RetroHexChat.Chat.AutoRespondRulesTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Chat.AutoRespondRules

  # ---------------------------------------------------------------------------
  # Unit tests
  # ---------------------------------------------------------------------------

  describe "new/0" do
    @tag :unit
    test "returns empty rules map" do
      assert %{entries: []} = AutoRespondRules.new()
    end
  end

  describe "add_entry/4" do
    @tag :unit
    test "adds a valid rule" do
      rules = AutoRespondRules.new()

      assert {:ok, updated} =
               AutoRespondRules.add_entry(rules, :on_join, "#test", "/notice $nick Welcome!")

      assert [entry] = updated.entries
      assert entry.trigger_event == :on_join
      assert entry.channel_filter == "#test"
      assert entry.command == "/notice $nick Welcome!"
      assert entry.enabled == true
      assert entry.position == 0
    end

    @tag :unit
    test "adds rule with nil channel_filter for global match" do
      rules = AutoRespondRules.new()

      assert {:ok, updated} =
               AutoRespondRules.add_entry(rules, :on_join, nil, "/notice $nick Hi!")

      assert [entry] = updated.entries
      assert entry.channel_filter == nil
    end

    @tag :unit
    test "rejects invalid trigger event" do
      rules = AutoRespondRules.new()

      assert {:error, :invalid_trigger} =
               AutoRespondRules.add_entry(rules, :on_kick, nil, "/say hi")
    end

    @tag :unit
    test "rejects command that is too long" do
      rules = AutoRespondRules.new()
      long_cmd = String.duplicate("a", 501)

      assert {:error, :command_too_long} =
               AutoRespondRules.add_entry(rules, :on_join, nil, long_cmd)
    end

    @tag :unit
    test "rejects when list is full at 10" do
      rules =
        Enum.reduce(0..9, AutoRespondRules.new(), fn i, acc ->
          {:ok, updated} = AutoRespondRules.add_entry(acc, :on_join, "#ch#{i}", "/say hi")
          updated
        end)

      assert {:error, :list_full} =
               AutoRespondRules.add_entry(rules, :on_join, "#extra", "/say hi")
    end

    @tag :unit
    test "rejects command with chaining characters" do
      rules = AutoRespondRules.new()

      assert {:error, :command_chaining} =
               AutoRespondRules.add_entry(rules, :on_join, nil, "/say hi && /say bye")
    end

    @tag :unit
    test "assigns sequential positions" do
      rules = AutoRespondRules.new()
      {:ok, rules} = AutoRespondRules.add_entry(rules, :on_join, nil, "/say hi")
      {:ok, rules} = AutoRespondRules.add_entry(rules, :on_part, nil, "/say bye")
      assert [first, second] = rules.entries
      assert first.position == 0
      assert second.position == 1
    end

    @tag :unit
    test "assigns unique ids to each entry" do
      rules = AutoRespondRules.new()
      {:ok, rules} = AutoRespondRules.add_entry(rules, :on_join, nil, "/say hi")
      {:ok, rules} = AutoRespondRules.add_entry(rules, :on_part, nil, "/say bye")
      [first, second] = rules.entries
      assert first.id != second.id
    end

    @tag :unit
    test "rejects invalid channel filter not starting with #" do
      rules = AutoRespondRules.new()

      assert {:error, :invalid_channel} =
               AutoRespondRules.add_entry(rules, :on_join, "badchannel", "/say hi")
    end
  end

  describe "remove_entry/2" do
    @tag :unit
    test "removes entry by position" do
      rules = AutoRespondRules.new()
      {:ok, rules} = AutoRespondRules.add_entry(rules, :on_join, nil, "/say hi")
      {:ok, rules} = AutoRespondRules.add_entry(rules, :on_part, nil, "/say bye")
      assert {:ok, updated} = AutoRespondRules.remove_entry(rules, 0)
      assert [entry] = updated.entries
      assert entry.command == "/say bye"
      assert entry.position == 0
    end

    @tag :unit
    test "returns error for non-existent position" do
      rules = AutoRespondRules.new()
      assert {:error, :not_found} = AutoRespondRules.remove_entry(rules, 0)
    end
  end

  describe "update_entry/3" do
    @tag :unit
    test "updates entry attributes" do
      rules = AutoRespondRules.new()
      {:ok, rules} = AutoRespondRules.add_entry(rules, :on_join, nil, "/say hi")

      assert {:ok, updated} =
               AutoRespondRules.update_entry(rules, 0, %{
                 command: "/notice $nick Welcome!",
                 channel_filter: "#test"
               })

      [entry] = updated.entries
      assert entry.command == "/notice $nick Welcome!"
      assert entry.channel_filter == "#test"
    end

    @tag :unit
    test "returns error for non-existent position" do
      rules = AutoRespondRules.new()
      assert {:error, :not_found} = AutoRespondRules.update_entry(rules, 5, %{command: "/say hi"})
    end

    @tag :unit
    test "rejects update with command chaining" do
      rules = AutoRespondRules.new()
      {:ok, rules} = AutoRespondRules.add_entry(rules, :on_join, nil, "/say hi")

      assert {:error, :command_chaining} =
               AutoRespondRules.update_entry(rules, 0, %{command: "/say hi | /say bye"})
    end
  end

  describe "toggle_entry/2" do
    @tag :unit
    test "toggles enabled flag" do
      rules = AutoRespondRules.new()
      {:ok, rules} = AutoRespondRules.add_entry(rules, :on_join, nil, "/say hi")
      assert {:ok, toggled} = AutoRespondRules.toggle_entry(rules, 0)
      [entry] = toggled.entries
      assert entry.enabled == false

      assert {:ok, toggled_back} = AutoRespondRules.toggle_entry(toggled, 0)
      [entry2] = toggled_back.entries
      assert entry2.enabled == true
    end

    @tag :unit
    test "returns error for non-existent position" do
      rules = AutoRespondRules.new()
      assert {:error, :not_found} = AutoRespondRules.toggle_entry(rules, 0)
    end
  end

  describe "matching_rules/3" do
    @tag :unit
    test "returns rules matching event type and channel" do
      rules = AutoRespondRules.new()
      {:ok, rules} = AutoRespondRules.add_entry(rules, :on_join, "#test", "/notice $nick Hi!")
      {:ok, rules} = AutoRespondRules.add_entry(rules, :on_part, "#test", "/say bye")
      {:ok, rules} = AutoRespondRules.add_entry(rules, :on_join, "#other", "/say other")

      matches = AutoRespondRules.matching_rules(rules, :on_join, "#test")
      assert length(matches) == 1
      assert hd(matches).command == "/notice $nick Hi!"
    end

    @tag :unit
    test "global rules (nil channel_filter) match any channel" do
      rules = AutoRespondRules.new()
      {:ok, rules} = AutoRespondRules.add_entry(rules, :on_join, nil, "/notice $nick Welcome!")

      matches = AutoRespondRules.matching_rules(rules, :on_join, "#anychannel")
      assert length(matches) == 1
    end

    @tag :unit
    test "excludes disabled rules" do
      rules = AutoRespondRules.new()
      {:ok, rules} = AutoRespondRules.add_entry(rules, :on_join, nil, "/say hi")
      {:ok, rules} = AutoRespondRules.toggle_entry(rules, 0)

      matches = AutoRespondRules.matching_rules(rules, :on_join, "#test")
      assert matches == []
    end

    @tag :unit
    test "returns empty list when no rules match" do
      rules = AutoRespondRules.new()
      {:ok, rules} = AutoRespondRules.add_entry(rules, :on_join, "#specific", "/say hi")

      matches = AutoRespondRules.matching_rules(rules, :on_join, "#other")
      assert matches == []
    end

    @tag :unit
    test "channel filter is case-insensitive" do
      rules = AutoRespondRules.new()
      {:ok, rules} = AutoRespondRules.add_entry(rules, :on_join, "#Test", "/say hi")

      matches = AutoRespondRules.matching_rules(rules, :on_join, "#test")
      assert length(matches) == 1
    end
  end

  describe "entries/1" do
    @tag :unit
    test "returns entries sorted by position" do
      rules = AutoRespondRules.new()
      {:ok, rules} = AutoRespondRules.add_entry(rules, :on_join, nil, "/say first")
      {:ok, rules} = AutoRespondRules.add_entry(rules, :on_part, nil, "/say second")

      entries = AutoRespondRules.entries(rules)
      assert length(entries) == 2
      assert hd(entries).command == "/say first"
    end
  end

  # ---------------------------------------------------------------------------
  # Integration tests (persistence)
  # ---------------------------------------------------------------------------

  describe "save/2 and load/1" do
    @tag :integration
    test "round-trip persistence" do
      owner = register_nick("responder_user")
      rules = AutoRespondRules.new()

      {:ok, rules} =
        AutoRespondRules.add_entry(rules, :on_join, "#test", "/notice $nick Welcome!")

      {:ok, rules} = AutoRespondRules.add_entry(rules, :on_part, nil, "/say $nick left")

      assert :ok = AutoRespondRules.save(owner, rules)
      assert {:ok, loaded} = AutoRespondRules.load(owner)
      assert length(loaded.entries) == 2

      first = hd(loaded.entries)
      assert first.trigger_event == :on_join
      assert first.channel_filter == "#test"
      assert first.command == "/notice $nick Welcome!"
    end

    @tag :integration
    test "load returns error when no data" do
      assert {:error, :not_found} = AutoRespondRules.load("nonexistent_user")
    end

    @tag :integration
    test "save overwrites previous data" do
      owner = register_nick("responder_save")
      rules = AutoRespondRules.new()
      {:ok, rules} = AutoRespondRules.add_entry(rules, :on_join, nil, "/say first")
      assert :ok = AutoRespondRules.save(owner, rules)

      rules2 = AutoRespondRules.new()
      {:ok, rules2} = AutoRespondRules.add_entry(rules2, :on_part, nil, "/say second")
      assert :ok = AutoRespondRules.save(owner, rules2)

      assert {:ok, loaded} = AutoRespondRules.load(owner)
      assert length(loaded.entries) == 1
      assert hd(loaded.entries).trigger_event == :on_part
    end
  end

  # ---------------------------------------------------------------------------
  # Helper
  # ---------------------------------------------------------------------------

  defp register_nick(nickname) do
    RetroHexChat.Repo.insert_all("registered_nicks", [
      %{
        nickname: nickname,
        password_hash: Bcrypt.hash_pwd_salt("password"),
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    ])

    nickname
  end
end
