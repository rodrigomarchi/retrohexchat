defmodule RetroHexChatWeb.Components.UI.GroupCall.PanelTest do
  @moduledoc """
  The channel permission matrix the conference panel draws its participant
  controls with, for every pair of channel roles. `CallSurfaceFlowTest` proves
  the rendered rows follow these answers for one pair per outcome.
  """
  use ExUnit.Case, async: true

  alias RetroHexChatWeb.Components.UI.GroupCall.Panel

  @moduletag :unit

  @roles ["owner", "operator", "half_operator", "voiced", "regular"]

  defp rank("owner"), do: 4
  defp rank("operator"), do: 3
  defp rank("half_operator"), do: 2
  defp rank("voiced"), do: 1
  defp rank("regular"), do: 0

  test "media moderation is offered from half-operator up, over a lower rank only" do
    for actor <- @roles, target <- @roles do
      expected = rank(actor) >= rank("half_operator") and rank(actor) > rank(target)

      assert Panel.moderates_role?(actor, target) == expected,
             "#{actor} over #{target}: expected #{expected}"
    end
  end

  test "remove-and-ban is offered to operators and owners, over a lower rank only" do
    for actor <- @roles, target <- @roles do
      expected = actor in ["owner", "operator"] and rank(actor) > rank(target)

      assert Panel.removes_role?(actor, target) == expected,
             "#{actor} over #{target}: expected #{expected}"
    end
  end

  test "the conference-wide controls are offered from half-operator up" do
    for role <- @roles do
      assert Panel.moderator_role?(role) == role in ["owner", "operator", "half_operator"]
    end

    refute Panel.moderator_role?(nil)
  end

  test "a role nobody knows offers nothing on either side" do
    for known <- @roles, unknown <- [nil, "founder"] do
      refute Panel.moderates_role?(known, unknown)
      refute Panel.moderates_role?(unknown, known)
      refute Panel.removes_role?(known, unknown)
      refute Panel.removes_role?(unknown, known)
    end
  end

  test "an atom role ranks as its name" do
    assert Panel.moderates_role?(:owner, "regular")
    refute Panel.moderates_role?(:regular, "owner")
  end
end
