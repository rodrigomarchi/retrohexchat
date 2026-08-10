defmodule RetroHexChat.Channels.RolesTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Channels.{Roles, Server, Supervisor}

  defp unique_channel, do: "#roles-#{System.unique_integer([:positive])}"

  defp start_channel(name) do
    {:ok, pid} = Supervisor.start_child(name)
    on_exit(fn -> if Process.alive?(pid), do: Supervisor.stop_child(pid) end)
    name
  end

  # The first person to join a channel becomes its owner, which is what gives
  # these tests an owner without reaching past the public API to make one.
  defp channel_owned_by(nickname) do
    name = start_channel(unique_channel())
    {:ok, _state} = Server.join(name, nickname)
    name
  end

  defp channel_joined_by(owner, nickname) do
    name = channel_owned_by(owner)
    {:ok, _state} = Server.join(name, nickname)
    name
  end

  describe "held_by/2" do
    test "reports nothing for someone in no channels" do
      assert Roles.held_by([], "Ada") == %{owner: [], operator: [], half_operator: []}
    end

    test "reports the channels someone owns" do
      owned = channel_owned_by("Ada")

      assert %{owner: [^owned]} = Roles.held_by([owned], "Ada")
    end

    test "owning a channel counts as operating it" do
      owned = channel_owned_by("Ada")

      assert %{owner: [^owned], operator: [^owned]} = Roles.held_by([owned], "Ada")
    end

    test "a plain member holds no role" do
      joined = channel_joined_by("Ada", "Mario")

      assert Roles.held_by([joined], "Mario") == %{
               owner: [],
               operator: [],
               half_operator: []
             }
    end

    test "an operator who is not the owner operates but does not own" do
      channel = channel_joined_by("Ada", "Mario")
      :ok = Server.set_mode(channel, "Ada", "+o", ["Mario"])

      assert %{owner: [], operator: [^channel]} = Roles.held_by([channel], "Mario")
    end

    test "a half-operator is reported apart from operators" do
      channel = channel_joined_by("Ada", "Mario")
      :ok = Server.set_mode(channel, "Ada", "+h", ["Mario"])

      assert %{owner: [], operator: [], half_operator: [^channel]} =
               Roles.held_by([channel], "Mario")
    end

    test "roles are reported per channel, not pooled" do
      owned = channel_owned_by("Ada")
      other = channel_joined_by("Mario", "Ada")

      held = Roles.held_by([owned, other], "Ada")

      assert held.owner == [owned]
      assert held.operator == [owned]
    end

    test "the caller's ordering is preserved" do
      first = channel_owned_by("Ada")
      second = channel_owned_by("Ada")

      assert %{owner: [^first, ^second]} = Roles.held_by([first, second], "Ada")
      assert %{owner: [^second, ^first]} = Roles.held_by([second, first], "Ada")
    end

    test "a channel with no running process is skipped rather than raising" do
      owned = channel_owned_by("Ada")

      assert %{owner: [^owned]} = Roles.held_by(["#never-started", owned], "Ada")
    end
  end
end
