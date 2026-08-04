defmodule RetroHexChat.Chat.ContextualTipsTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Chat.ContextualTips
  alias RetroHexChat.Services.Queries

  describe "new/0" do
    @tag :unit
    test "starts unsuppressed with no seen tips" do
      tips = ContextualTips.new()

      refute ContextualTips.suppressed?(tips)
      assert ContextualTips.seen_tips(tips) == []
    end
  end

  describe "mark_seen/2 and set_suppressed/2" do
    @tag :unit
    test "marks known tips and ignores unknown values" do
      tips =
        ContextualTips.new()
        |> ContextualTips.mark_seen("first_message")
        |> ContextualTips.mark_seen("unknown")
        |> ContextualTips.mark_seen(nil)
        |> ContextualTips.mark_seen("first_message")

      assert ContextualTips.seen?(tips, "first_message")
      assert ContextualTips.seen_tips(tips) == ["first_message"]
    end

    @tag :unit
    test "preempting help marks idle_help as seen" do
      tips = ContextualTips.mark_preempted(ContextualTips.new(), "help_used")

      assert ContextualTips.seen?(tips, "idle_help")
    end

    @tag :unit
    test "suppression accepts booleans only" do
      tips = ContextualTips.new() |> ContextualTips.set_suppressed(true)

      assert ContextualTips.suppressed?(tips)
      assert ContextualTips.set_suppressed(tips, "false") == tips
      refute tips |> ContextualTips.set_suppressed(false) |> ContextualTips.suppressed?()
    end
  end

  describe "to_client_state/1" do
    @tag :unit
    test "returns a JSON-safe map" do
      tips =
        ContextualTips.new()
        |> ContextualTips.mark_seen("first_join")
        |> ContextualTips.set_suppressed(true)

      assert ContextualTips.to_client_state(tips) == %{
               seen_tips: ["first_join"],
               suppressed: true
             }
    end
  end

  describe "save/2 and load/1" do
    @tag :integration
    test "round-trips through the database" do
      nick = "TipUser1"
      insert_registered_nick(nick)

      tips =
        ContextualTips.new()
        |> ContextualTips.mark_seen("first_message")
        |> ContextualTips.mark_seen("idle_help")
        |> ContextualTips.set_suppressed(true)

      assert :ok = ContextualTips.save(nick, tips)

      assert {:ok, loaded} = ContextualTips.load(nick)
      assert ContextualTips.suppressed?(loaded)
      assert ContextualTips.seen_tips(loaded) == ["first_message", "idle_help"]
    end

    @tag :integration
    test "save overwrites and normalizes invalid state" do
      nick = "TipUser2"
      insert_registered_nick(nick)

      assert :ok =
               ContextualTips.save(
                 nick,
                 ContextualTips.mark_seen(ContextualTips.new(), "first_pm")
               )

      assert :ok =
               ContextualTips.save(nick, %{
                 seen_tips: ["unknown", "first_join", "first_join", nil],
                 suppressed: "true"
               })

      assert {:ok, loaded} = ContextualTips.load(nick)
      assert ContextualTips.seen_tips(loaded) == ["first_join"]
      refute ContextualTips.suppressed?(loaded)
    end

    @tag :integration
    test "load returns not_found when absent" do
      assert {:error, :not_found} = ContextualTips.load("MissingTipUser")
    end
  end

  defp insert_registered_nick(nickname) do
    {:ok, _} = Queries.insert_registered_nick(nickname, "password123")
  end
end
