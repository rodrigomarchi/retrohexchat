defmodule RetroHexChat.Commands.Handlers.P2pTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Commands.Handlers.P2p
  alias RetroHexChat.P2P.{RateLimiter, RateLimitTable}
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :integration

  @base_context %{
    nickname: "rodrigo",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: true,
    operator_in: [],
    half_operator_in: [],
    is_admin: false,
    is_server_operator: false
  }

  describe "validate/1" do
    test "rejects empty args" do
      assert {:error, _} = P2p.validate("")
    end

    test "accepts valid nick" do
      assert :ok = P2p.validate("mario")
    end
  end

  describe "execute/2" do
    test "returns p2p_invite ui_action with target and token" do
      # Create registered nicks for the test
      {:ok, creator} =
        %RegisteredNick{}
        |> RegisteredNick.registration_changeset(%{
          nickname: "rodrigo",
          password: "password123"
        })
        |> Repo.insert()

      {:ok, _peer} =
        %RegisteredNick{}
        |> RegisteredNick.registration_changeset(%{
          nickname: "mario",
          password: "password123"
        })
        |> Repo.insert()

      context = %{@base_context | nickname: "rodrigo", identified: true}
      result = P2p.execute(["mario"], context)

      assert {:ok, :ui_action, :p2p_invite, payload} = result
      assert payload.target == "mario"
      assert payload.session_type == "generic"
      assert payload.token != nil
      assert payload.creator_id == creator.id
    end

    test "rejects empty args" do
      assert {:error, _} = P2p.execute([], @base_context)
    end

    test "rejects when not identified" do
      context = %{@base_context | identified: false}
      assert {:error, msg} = P2p.execute(["mario"], context)
      assert msg =~ "identified"
    end

    test "rejects targeting self" do
      context = %{@base_context | nickname: "rodrigo"}
      assert {:error, msg} = P2p.execute(["rodrigo"], context)
      assert msg =~ "yourself"
    end

    test "rejects unregistered target" do
      # Creator registered but target not
      {:ok, _creator} =
        %RegisteredNick{}
        |> RegisteredNick.registration_changeset(%{
          nickname: "p2p_cr1",
          password: "password123"
        })
        |> Repo.insert()

      context = %{@base_context | nickname: "p2p_cr1"}
      assert {:error, msg} = P2p.execute(["nobody"], context)
      assert msg =~ "not registered"
    end
  end

  describe "rate limiting" do
    test "rejects session creation when rate limit exceeded" do
      {:ok, creator} =
        %RegisteredNick{}
        |> RegisteredNick.registration_changeset(%{
          nickname: "p2p_rl_creator",
          password: "password123"
        })
        |> Repo.insert()

      # Create 6 different peers (need unique peer for each session due to active session check)
      peers =
        for i <- 1..6 do
          {:ok, peer} =
            %RegisteredNick{}
            |> RegisteredNick.registration_changeset(%{
              nickname: "p2p_rl_peer#{i}",
              password: "password123"
            })
            |> Repo.insert()

          peer
        end

      context = %{@base_context | nickname: "p2p_rl_creator"}

      # Exhaust rate limit (default 5 in test config)
      for peer <- Enum.take(peers, 5) do
        {:ok, :ui_action, :p2p_invite, _} = P2p.execute([peer.nickname], context)
      end

      # 6th should be rate limited
      sixth_peer = Enum.at(peers, 5)
      assert {:error, msg} = P2p.execute([sixth_peer.nickname], context)
      assert msg =~ "Too many sessions"

      # Clean up rate limit
      RateLimiter.reset(RateLimitTable.table_name(), creator.id)
    end
  end

  describe "help/0" do
    test "returns help map with required keys" do
      help = P2p.help()
      assert help.name == "p2p"
      assert help.syntax =~ "/p2p"
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end

  describe "category/0" do
    test "returns :user" do
      assert P2p.category() == :user
    end
  end
end
