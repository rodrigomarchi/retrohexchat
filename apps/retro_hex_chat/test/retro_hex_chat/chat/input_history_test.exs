defmodule RetroHexChat.Chat.InputHistoryTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Chat.InputHistory
  alias RetroHexChat.Services.Queries

  describe "new/0" do
    @tag :unit
    test "starts empty" do
      history = InputHistory.new()

      assert InputHistory.entries(history) == []
      assert InputHistory.recent_commands(history) == []
    end
  end

  describe "record_submission/2" do
    @tag :unit
    test "records non-empty input most recent first and deduplicates" do
      history =
        InputHistory.new()
        |> InputHistory.record_submission("hello")
        |> InputHistory.record_submission("/join #lobby")
        |> InputHistory.record_submission("hello")

      assert InputHistory.entries(history) == ["hello", "/join #lobby"]
    end

    @tag :unit
    test "ignores empty and non-binary input" do
      history =
        InputHistory.new()
        |> InputHistory.record_submission("")
        |> InputHistory.record_submission("   ")
        |> InputHistory.record_submission(nil)

      assert InputHistory.entries(history) == []
    end

    @tag :unit
    test "does not record NickServ secrets or automation that embeds them" do
      history =
        InputHistory.new()
        |> InputHistory.record_submission("/identify secret")
        |> InputHistory.record_submission("/NS identify secret")
        |> InputHistory.record_submission("/msg NickServ identify secret")
        |> InputHistory.record_submission("/perform add /ns identify secret")

      assert InputHistory.entries(history) == []
      assert InputHistory.recent_commands(history) == []
    end

    @tag :unit
    test "tracks recent non-sensitive command names" do
      history =
        InputHistory.new()
        |> InputHistory.record_submission("/join #lobby")
        |> InputHistory.record_submission("/away lunch")
        |> InputHistory.record_submission("/JOIN #dev")

      assert InputHistory.recent_commands(history) == ["join", "away"]
    end

    @tag :unit
    test "caps entries and recent commands" do
      history =
        Enum.reduce(1..110, InputHistory.new(), fn index, acc ->
          InputHistory.record_submission(acc, "/cmd#{index}")
        end)

      assert length(InputHistory.entries(history)) == 100
      assert hd(InputHistory.entries(history)) == "/cmd110"
      assert length(InputHistory.recent_commands(history)) == 5
      assert InputHistory.recent_commands(history) == ~w(cmd110 cmd109 cmd108 cmd107 cmd106)
    end

    @tag :unit
    test "drops oversized entries" do
      oversized = String.duplicate("x", 1001)

      history =
        InputHistory.new()
        |> InputHistory.record_submission(oversized)
        |> InputHistory.record_submission("/join #ok")

      assert InputHistory.entries(history) == ["/join #ok"]
    end
  end

  describe "save/2 and load/1" do
    @tag :integration
    test "round-trips history through the database" do
      nick = "HistUser1"
      insert_registered_nick(nick)

      history =
        InputHistory.new()
        |> InputHistory.record_submission("hello")
        |> InputHistory.record_submission("/join #lobby")

      assert :ok = InputHistory.save(nick, history)

      assert {:ok, loaded} = InputHistory.load(nick)
      assert InputHistory.entries(loaded) == ["/join #lobby", "hello"]
      assert InputHistory.recent_commands(loaded) == ["join"]
    end

    @tag :integration
    test "save overwrites and normalizes existing history" do
      nick = "HistUser2"
      insert_registered_nick(nick)

      first = InputHistory.record_submission(InputHistory.new(), "/join #first")
      assert :ok = InputHistory.save(nick, first)

      second = %{
        entries: ["ok", "", String.duplicate("x", 1001), "ok"],
        recent_commands: ["away", "", "join", "away"]
      }

      assert :ok = InputHistory.save(nick, second)

      assert {:ok, loaded} = InputHistory.load(nick)
      assert InputHistory.entries(loaded) == ["ok"]
      assert InputHistory.recent_commands(loaded) == ["away", "join"]
    end

    @tag :integration
    test "load returns not_found when absent" do
      assert {:error, :not_found} = InputHistory.load("MissingHistory")
    end
  end

  defp insert_registered_nick(nickname) do
    {:ok, _} = Queries.insert_registered_nick(nickname, "password123")
  end
end
