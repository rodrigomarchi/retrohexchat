defmodule RetroHexChat.ShareLinks.Schema.LinkTest do
  @moduledoc """
  What a share link is allowed to be, at the changeset boundary.

  The kind decides which surface the slug resolves to, so an unknown kind is
  refused here rather than discovered by a resolver with no clause for it.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.ShareLinks.Schema.Link

  @valid %{
    slug: "abcdefghjk",
    kind: "call",
    target: %{"room_token" => "tok", "channel_name" => "#retro"},
    creator_id: 1,
    creator_nick: "ana"
  }

  test "accepts the known kinds and nothing else" do
    for kind <- ~w(call space p2p play) do
      assert changeset(%{kind: kind}).valid?
    end

    assert changeset(%{kind: "channel", target: %{"channel" => "#retro"}}).valid?

    refute changeset(%{kind: "chat"}).valid?
    refute changeset(%{kind: ""}).valid?
  end

  describe "a channel link's target" do
    test "names one channel" do
      assert changeset(%{kind: "channel", target: %{"channel" => "#retro"}}).valid?
    end

    test "is refused when it names nothing, or something that is not a channel" do
      for target <- [%{}, %{"channel" => ""}, %{"channel" => "retro"}, %{"channel" => 7}] do
        refute changeset(%{kind: "channel", target: target}).valid?,
               "#{inspect(target)} should not name a channel"
      end
    end

    test "is refused when the name is longer than a channel name may be" do
      long = "#" <> String.duplicate("a", 60)

      refute changeset(%{kind: "channel", target: %{"channel" => long}}).valid?
    end
  end

  test "requires the slug, the kind and who made it" do
    for field <- [:slug, :kind, :creator_id, :creator_nick] do
      changeset = changeset(Map.new([{field, nil}]))

      refute changeset.valid?, "#{field} should be required"
      assert Keyword.has_key?(changeset.errors, field)
    end
  end

  test "refuses a slug the generator could not have produced" do
    refute changeset(%{slug: "SHOUTING1"}).valid?
    refute changeset(%{slug: "short"}).valid?
  end

  test "target defaults to empty rather than nil, so a resolver never matches on nil" do
    changeset = changeset(%{target: nil})

    assert Ecto.Changeset.get_field(changeset, :target) == %{}
  end

  describe "revoking" do
    test "records who and when together" do
      changeset =
        Link.revoke_changeset(%Link{}, %{revoked_at: DateTime.utc_now(), revoked_by: "ana"})

      assert changeset.valid?
    end

    test "refuses a revocation with no hand on it" do
      changeset = Link.revoke_changeset(%Link{}, %{revoked_at: DateTime.utc_now()})

      refute changeset.valid?
    end
  end

  defp changeset(overrides), do: Link.changeset(%Link{}, Map.merge(@valid, overrides))
end
