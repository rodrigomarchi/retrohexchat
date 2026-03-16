defmodule RetroHexChat.Commands.AutocompleteTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Autocomplete

  describe "fuzzy_match/2" do
    test "empty query matches everything with score 0" do
      assert {:match, 0, []} = Autocomplete.fuzzy_match("", "join")
      assert {:match, 0, []} = Autocomplete.fuzzy_match("", "")
    end

    test "exact prefix match scores highest with length bonus" do
      {:match, score, indices} = Autocomplete.fuzzy_match("jo", "join")

      assert score == 1000 + String.length("join")
      assert indices == [0, 1]
    end

    test "full exact match scores highest" do
      {:match, score, indices} = Autocomplete.fuzzy_match("join", "join")

      assert score == 1000 + String.length("join")
      assert indices == [0, 1, 2, 3]
    end

    test "prefix match is case-insensitive" do
      {:match, score_lower, _} = Autocomplete.fuzzy_match("jo", "join")
      {:match, score_upper, _} = Autocomplete.fuzzy_match("JO", "join")
      {:match, score_mixed, _} = Autocomplete.fuzzy_match("Jo", "JOIN")

      assert score_lower == score_upper
      assert score_lower == score_mixed
    end

    test "word-boundary subsequence scores medium" do
      {:match, score, _indices} = Autocomplete.fuzzy_match("cb", "clear-buffer")

      assert score == 500
    end

    test "general subsequence scores lowest" do
      {:match, score, indices} = Autocomplete.fuzzy_match("jn", "join")

      # j matches index 0, n matches index 3
      assert score == 100
      assert indices == [0, 3]
    end

    test "non-matching query returns :no_match" do
      assert :no_match = Autocomplete.fuzzy_match("xyz", "join")
      assert :no_match = Autocomplete.fuzzy_match("zz", "abc")
    end

    test "matched character indices are correct for prefix" do
      {:match, _, indices} = Autocomplete.fuzzy_match("joi", "join")

      assert indices == [0, 1, 2]
    end

    test "matched character indices are correct for subsequence" do
      {:match, _, indices} = Autocomplete.fuzzy_match("jn", "join")

      assert indices == [0, 3]
    end

    test "longer prefix still matches correctly" do
      {:match, score, indices} = Autocomplete.fuzzy_match("auto", "autojoin")

      assert score == 1000 + String.length("autojoin")
      assert indices == [0, 1, 2, 3]
    end

    test "single character matches as prefix" do
      {:match, score, indices} = Autocomplete.fuzzy_match("j", "join")

      assert score == 1000 + String.length("join")
      assert indices == [0]
    end

    test "query longer than candidate returns :no_match" do
      assert :no_match = Autocomplete.fuzzy_match("joining", "join")
    end

    test "subsequence with non-adjacent characters" do
      {:match, score, indices} = Autocomplete.fuzzy_match("at", "autojoin")

      # a at 0, t at 2 — but "at" is not a prefix of "autojoin" (prefix is "au")
      # "a" matches at 0, "t" matches at 2
      assert score == 100
      assert 0 in indices
    end

    test "word boundary match with underscore separator" do
      {:match, score, _} = Autocomplete.fuzzy_match("sc", "set_config")

      assert score == 500
    end

    test "word boundary match with hyphen separator" do
      {:match, score, _} = Autocomplete.fuzzy_match("nm", "nick-match")

      assert score == 500
    end

    test "prefix match beats word-boundary match in score" do
      {:match, prefix_score, _} = Autocomplete.fuzzy_match("cl", "clear")
      {:match, boundary_score, _} = Autocomplete.fuzzy_match("cb", "clear-buffer")

      assert prefix_score > boundary_score
    end

    test "word-boundary match beats general subsequence in score" do
      {:match, boundary_score, _} = Autocomplete.fuzzy_match("cb", "clear-buffer")
      {:match, subseq_score, _} = Autocomplete.fuzzy_match("cr", "clear")

      assert boundary_score > subseq_score
    end
  end

  describe "search_commands/2" do
    test "empty query returns all commands" do
      results = Autocomplete.search_commands("", [])
      assert results != []
      assert length(results) <= 20
    end

    test "fuzzy query returns matching commands with scores" do
      results = Autocomplete.search_commands("jo", [])

      names = Enum.map(results, & &1.name)
      assert "join" in names
      assert "autojoin" in names
    end

    test "results include category information" do
      results = Autocomplete.search_commands("join", [])

      join = Enum.find(results, &(&1.name == "join"))
      assert join.type == :command
      assert join.category == "Channel"
      assert is_list(join.matched_chars)
    end

    test "recent commands are marked as recent" do
      results = Autocomplete.search_commands("jo", ["join"])

      join = Enum.find(results, &(&1.name == "join"))
      autojoin = Enum.find(results, &(&1.name == "autojoin"))

      assert join.recent?
      refute autojoin.recent?
    end

    test "results sorted by score descending" do
      results = Autocomplete.search_commands("jo", [])
      scores = Enum.map(results, & &1.score)

      assert scores == Enum.sort(scores, :desc)
    end

    test "non-matching query returns empty list" do
      results = Autocomplete.search_commands("zzzzz", [])
      assert results == []
    end

    test "results capped at 20" do
      results = Autocomplete.search_commands("", [])
      assert length(results) <= 20
    end
  end

  # ── US2: Nick Autocomplete ──────────────────────────────

  describe "search_nicks/3" do
    @channel_users [
      %{nickname: "Mario", away: false, away_message: nil},
      %{nickname: "Marcelo", away: false, away_message: nil},
      %{nickname: "Martin", away: true, away_message: "brb"},
      %{nickname: "Zelda", away: false, away_message: nil},
      %{nickname: "TestUser", away: false, away_message: nil}
    ]

    test "fuzzy match on nicknames" do
      results = Autocomplete.search_nicks("mar", @channel_users, "TestUser")

      names = Enum.map(results, & &1.nickname)
      assert "Mario" in names
      assert "Marcelo" in names
      assert "Martin" in names
      refute "Zelda" in names
    end

    test "online users sorted before away users" do
      results = Autocomplete.search_nicks("mar", @channel_users, "TestUser")

      statuses = Enum.map(results, & &1.status)

      online_indices =
        Enum.with_index(statuses)
        |> Enum.filter(fn {s, _} -> s == :online end)
        |> Enum.map(&elem(&1, 1))

      away_indices =
        Enum.with_index(statuses)
        |> Enum.filter(fn {s, _} -> s == :away end)
        |> Enum.map(&elem(&1, 1))

      if online_indices != [] and away_indices != [] do
        assert Enum.max(online_indices) < Enum.min(away_indices)
      end
    end

    test "own nick deprioritized to end of list" do
      users = [
        %{nickname: "Alice", away: false, away_message: nil},
        %{nickname: "Aaron", away: false, away_message: nil},
        %{nickname: "Abel", away: false, away_message: nil}
      ]

      results = Autocomplete.search_nicks("a", users, "Alice")

      names = Enum.map(results, & &1.nickname)
      assert List.last(names) == "Alice"
    end

    test "empty query returns all channel users sorted" do
      results = Autocomplete.search_nicks("", @channel_users, "TestUser")

      assert length(results) == length(@channel_users)
    end

    test "results capped at 20" do
      many_users =
        for i <- 1..25 do
          %{nickname: "User#{i}", away: false, away_message: nil}
        end

      results = Autocomplete.search_nicks("user", many_users, "Nobody")
      assert length(results) <= 20
    end

    test "status field correctly set from user data" do
      results = Autocomplete.search_nicks("mar", @channel_users, "TestUser")

      martin = Enum.find(results, &(&1.nickname == "Martin"))
      mario = Enum.find(results, &(&1.nickname == "Mario"))

      assert martin.status == :away
      assert martin.away_message == "brb"
      assert mario.status == :online
    end

    test "self? flag is set correctly" do
      results = Autocomplete.search_nicks("", @channel_users, "Mario")

      mario = Enum.find(results, &(&1.nickname == "Mario"))
      marcelo = Enum.find(results, &(&1.nickname == "Marcelo"))

      assert mario.self?
      refute marcelo.self?
    end

    test "results include matched_chars" do
      results = Autocomplete.search_nicks("mar", @channel_users, "TestUser")

      mario = Enum.find(results, &(&1.nickname == "Mario"))
      assert is_list(mario.matched_chars)
      assert mario.matched_chars == [0, 1, 2]
    end

    test "non-matching query returns empty list" do
      results = Autocomplete.search_nicks("zzz", @channel_users, "TestUser")
      assert results == []
    end
  end

  describe "tab_complete_matches/3" do
    @tab_users [
      %{nickname: "Mario", away: false, away_message: nil},
      %{nickname: "Marcelo", away: false, away_message: nil},
      %{nickname: "Martin", away: false, away_message: nil},
      %{nickname: "Zelda", away: false, away_message: nil}
    ]

    test "returns alphabetically sorted matching nicks" do
      matches = Autocomplete.tab_complete_matches("Mar", @tab_users, "Zelda")

      assert matches == ["Marcelo", "Mario", "Martin"]
    end

    test "single match returns one-element list" do
      matches = Autocomplete.tab_complete_matches("Zel", @tab_users, "Mario")

      assert matches == ["Zelda"]
    end

    test "no matches returns empty list" do
      matches = Autocomplete.tab_complete_matches("Xyz", @tab_users, "Mario")

      assert matches == []
    end

    test "case-insensitive prefix matching" do
      matches = Autocomplete.tab_complete_matches("mar", @tab_users, "Zelda")

      assert matches == ["Marcelo", "Mario", "Martin"]
    end

    test "own nick excluded from first position" do
      matches = Autocomplete.tab_complete_matches("Mar", @tab_users, "Mario")

      # Mario should be at the end, not first
      assert List.last(matches) == "Mario"
      assert hd(matches) != "Mario"
    end
  end

  # ── US3: Argument Context ──────────────────────────────

  describe "argument_context/1" do
    test "msg expects nick from all channels" do
      assert {:nick, :all_channels} = Autocomplete.argument_context("msg")
    end

    test "query expects nick from all channels" do
      assert {:nick, :all_channels} = Autocomplete.argument_context("query")
    end

    test "whois expects nick from all channels" do
      assert {:nick, :all_channels} = Autocomplete.argument_context("whois")
    end

    test "whowas expects nick from all channels" do
      assert {:nick, :all_channels} = Autocomplete.argument_context("whowas")
    end

    test "notice expects nick from all channels" do
      assert {:nick, :all_channels} = Autocomplete.argument_context("notice")
    end

    test "kick expects nick from current channel" do
      assert {:nick, :current_channel} = Autocomplete.argument_context("kick")
    end

    test "ban expects nick from current channel" do
      assert {:nick, :current_channel} = Autocomplete.argument_context("ban")
    end

    test "join expects channel" do
      assert {:channel, :all} = Autocomplete.argument_context("join")
    end

    test "part expects channel" do
      assert {:channel, :all} = Autocomplete.argument_context("part")
    end

    test "topic expects channel" do
      assert {:channel, :all} = Autocomplete.argument_context("topic")
    end

    test "mode expects channel" do
      assert {:channel, :all} = Autocomplete.argument_context("mode")
    end

    test "invite expects nick" do
      assert {:nick, :all_channels} = Autocomplete.argument_context("invite")
    end

    test "help returns nil (no completion)" do
      assert nil == Autocomplete.argument_context("help")
    end

    test "clear returns nil (no completion)" do
      assert nil == Autocomplete.argument_context("clear")
    end

    test "unknown command returns nil" do
      assert nil == Autocomplete.argument_context("nonexistent")
    end
  end

  # ── US4: Channel Autocomplete ──────────────────────────

  describe "search_channels/2" do
    test "fuzzy match on channel names without # prefix" do
      channels = [
        %{name: "#dev", user_count: 5, topic: "Development", secret?: false},
        %{name: "#design", user_count: 3, topic: "Design talk", secret?: false},
        %{name: "#lobby", user_count: 10, topic: "Welcome", secret?: false}
      ]

      results = Autocomplete.search_channels("de", ["#lobby"], channels)

      names = Enum.map(results, & &1.name)
      assert "#dev" in names
      assert "#design" in names
      refute "#lobby" in names
    end

    test "joined channels sorted first" do
      channels = [
        %{name: "#alpha", user_count: 3, topic: nil, secret?: false},
        %{name: "#beta", user_count: 5, topic: nil, secret?: false}
      ]

      results = Autocomplete.search_channels("", ["#beta"], channels)

      names = Enum.map(results, & &1.name)
      assert hd(names) == "#beta"
    end

    test "joined? flag set correctly" do
      channels = [
        %{name: "#alpha", user_count: 3, topic: nil, secret?: false},
        %{name: "#beta", user_count: 5, topic: nil, secret?: false}
      ]

      results = Autocomplete.search_channels("", ["#beta"], channels)

      beta = Enum.find(results, &(&1.name == "#beta"))
      alpha = Enum.find(results, &(&1.name == "#alpha"))

      assert beta.joined?
      refute alpha.joined?
    end

    test "results capped at 20" do
      channels =
        for i <- 1..25 do
          %{name: "#ch#{i}", user_count: i, topic: nil, secret?: false}
        end

      results = Autocomplete.search_channels("ch", [], channels)
      assert length(results) <= 20
    end

    test "non-matching returns empty" do
      channels = [
        %{name: "#dev", user_count: 5, topic: nil, secret?: false}
      ]

      results = Autocomplete.search_channels("zzz", [], channels)
      assert results == []
    end

    test "user_count populated in results" do
      channels = [
        %{name: "#dev", user_count: 5, topic: "Dev topic", secret?: false}
      ]

      results = Autocomplete.search_channels("dev", [], channels)

      dev = Enum.find(results, &(&1.name == "#dev"))
      assert dev.user_count == 5
    end
  end

  # ── Subcommand Autocomplete ─────────────────────────────

  describe "search_subcommands/2" do
    test "returns all subcommands with empty partial" do
      results = Autocomplete.search_subcommands("ns", "")
      assert length(results) == 6
      assert Enum.all?(results, &(&1.type == :subcommand))
      names = Enum.map(results, & &1.name)
      assert "register" in names
      assert "identify" in names
    end

    test "fuzzy matches subcommand name" do
      results = Autocomplete.search_subcommands("ns", "reg")
      assert results != []
      assert hd(results).name == "register"
    end

    test "returns empty for no match" do
      assert Autocomplete.search_subcommands("ns", "xyz") == []
    end

    test "returns empty for unknown command" do
      assert Autocomplete.search_subcommands("unknown_cmd", "") == []
    end

    test "returns empty for command without subcommands" do
      assert Autocomplete.search_subcommands("kick", "") == []
    end

    test "includes matched_chars in results" do
      results = Autocomplete.search_subcommands("ns", "reg")
      result = hd(results)
      assert is_list(result.matched_chars)
      assert result.matched_chars == [0, 1, 2]
    end

    test "works for all commands with subcommands" do
      for {cmd, expected_count} <- [
            {"ns", 6},
            {"cs", 7},
            {"autojoin", 4},
            {"alias", 3},
            {"notify", 4},
            {"perform", 5},
            {"autorespond", 3},
            {"timer", 2}
          ] do
        results = Autocomplete.search_subcommands(cmd, "")

        assert length(results) == expected_count,
               "Expected #{expected_count} subcommands for /#{cmd}, got #{length(results)}"
      end
    end
  end
end
