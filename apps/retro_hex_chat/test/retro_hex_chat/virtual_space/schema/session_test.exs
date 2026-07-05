defmodule RetroHexChat.VirtualSpace.Schema.SessionTest do
  use RetroHexChat.DataCase, async: true

  import RetroHexChat.Factory

  alias RetroHexChat.VirtualSpace.Schema.Session

  @moduletag :unit

  defp valid_attrs(creator_id) do
    %{
      token: "space-#{System.unique_integer([:positive])}",
      channel_name: "#retro",
      creator_id: creator_id,
      creator_nick: "creator",
      title: "Tavern hangout"
    }
  end

  describe "changeset/2" do
    test "is valid with defaults applied" do
      creator = insert(:registered_nick)
      changeset = Session.changeset(%Session{}, valid_attrs(creator.id))

      assert changeset.valid?

      session = Ecto.Changeset.apply_changes(changeset)
      assert session.status == "pending"
      assert session.map_id == "tavern_cafe_v1"
      assert session.max_participants == 20
    end

    test "rejects a status outside the lifecycle" do
      creator = insert(:registered_nick)
      attrs = Map.put(valid_attrs(creator.id), :status, "dancing")

      changeset = Session.changeset(%Session{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end

    test "accepts every lifecycle status" do
      creator = insert(:registered_nick)

      for status <- ~w(pending active closed expired failed) do
        attrs = Map.put(valid_attrs(creator.id), :status, status)
        changeset = Session.changeset(%Session{}, attrs)
        assert changeset.valid?, "expected #{status} to be a valid status"
      end
    end

    test "requires token, channel_name and creator_id" do
      changeset = Session.changeset(%Session{}, %{})

      errors = errors_on(changeset)
      assert "can't be blank" in errors.token
      assert "can't be blank" in errors.channel_name
      assert "can't be blank" in errors.creator_id
    end

    test "enforces token uniqueness" do
      creator = insert(:registered_nick)
      attrs = valid_attrs(creator.id)

      assert {:ok, _session} =
               %Session{} |> Session.changeset(attrs) |> Repo.insert()

      assert {:error, changeset} =
               %Session{} |> Session.changeset(attrs) |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).token
    end
  end

  describe "terminal?/1" do
    test "is true for closed, expired and failed" do
      for status <- ~w(closed expired failed) do
        assert Session.terminal?(status)
      end
    end

    test "is false for pending and active" do
      for status <- ~w(pending active) do
        refute Session.terminal?(status)
      end
    end
  end
end
