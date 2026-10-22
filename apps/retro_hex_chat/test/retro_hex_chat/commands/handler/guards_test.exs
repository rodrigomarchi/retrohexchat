defmodule RetroHexChat.Commands.Handler.GuardsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  import RetroHexChat.Commands.Handler.Guards

  @base_context %{
    nickname: "Alice",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: [],
    half_operator_in: []
  }

  describe "require_channel/1" do
    test "returns the active channel" do
      assert {:ok, "#lobby"} = require_channel(@base_context)
    end

    test "refuses when there is no active channel" do
      assert {:error, "You are not in any channel"} =
               require_channel(%{@base_context | active_channel: nil})
    end
  end

  describe "require_operator/3" do
    test "accepts an operator of the channel" do
      ctx = %{@base_context | operator_in: ["#lobby"]}

      assert :ok = require_operator(ctx, "#lobby")
    end

    test "refuses an operator of a different channel" do
      ctx = %{@base_context | operator_in: ["#other"]}

      assert {:error, "You must be a channel operator to use this command"} =
               require_operator(ctx, "#lobby")
    end

    test "refuses a half-operator" do
      ctx = %{@base_context | half_operator_in: ["#lobby"]}

      assert {:error, _} = require_operator(ctx, "#lobby")
    end

    test "carries the caller's own refusal message" do
      assert {:error, "You must be a channel operator to ban users"} =
               require_operator(
                 @base_context,
                 "#lobby",
                 "You must be a channel operator to ban users"
               )
    end
  end

  describe "require_half_op_or_above/3" do
    test "accepts an operator" do
      ctx = %{@base_context | operator_in: ["#lobby"]}

      assert :ok = require_half_op_or_above(ctx, "#lobby")
    end

    test "accepts a half-operator" do
      ctx = %{@base_context | half_operator_in: ["#lobby"]}

      assert :ok = require_half_op_or_above(ctx, "#lobby")
    end

    test "refuses a plain member" do
      assert {:error, "You must be at least a half-operator to use this command"} =
               require_half_op_or_above(@base_context, "#lobby")
    end

    test "treats a context without half_operator_in as having none" do
      ctx = Map.delete(@base_context, :half_operator_in)

      assert {:error, _} = require_half_op_or_above(ctx, "#lobby")
    end

    test "carries the caller's own refusal message" do
      assert {:error, "You must be a channel operator to kick users"} =
               require_half_op_or_above(
                 @base_context,
                 "#lobby",
                 "You must be a channel operator to kick users"
               )
    end
  end

  describe "require_identified/2" do
    test "passes an identified nickname" do
      assert :ok = require_identified(%{identified: true})
    end

    test "refuses one that is not, or has no word on it, in the command's terms when given" do
      assert {:error, _} = require_identified(%{identified: false})
      assert {:error, _} = require_identified(%{})
      assert {:error, "Identify first"} = require_identified(%{}, "Identify first")
    end
  end

  describe "require_owner/3" do
    test "passes the channel's owner and refuses anyone else" do
      assert :ok = require_owner(%{owner_in: ["#lobby"]}, "#lobby")
      assert {:error, _} = require_owner(%{owner_in: ["#other"]}, "#lobby")
      assert {:error, _} = require_owner(%{}, "#lobby")
    end
  end
end
