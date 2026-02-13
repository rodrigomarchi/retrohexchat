defmodule RetroHexChat.Services.ChanServAutoPrivilegeTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  import RetroHexChat.Factory

  alias RetroHexChat.Channels.{Server, Supervisor}

  defp unique_channel, do: "#autoprivtest-#{System.unique_integer([:positive])}"

  defp start_registered_channel(channel_name, founder_nickname) do
    insert(:registered_channel, name: channel_name, founder_nickname: founder_nickname)
    {:ok, pid} = Supervisor.start_child(channel_name)

    on_exit(fn ->
      if Process.alive?(pid), do: Supervisor.stop_child(pid)
    end)

    {:ok, pid}
  end

  describe "auto-privilege on join for registered channels" do
    test "user with 'aop' access level gets :operator role" do
      channel = unique_channel()
      founder = "Founder#{System.unique_integer([:positive])}"
      user = "AopUser#{System.unique_integer([:positive])}"

      start_registered_channel(channel, founder)

      insert(:access_list_entry,
        channel_name: channel,
        nickname: user,
        level: "aop",
        added_by: founder
      )

      {:ok, state} = Server.join(channel, user)
      assert {user, :operator} in state.members
    end

    test "user with 'vop' access level gets :voiced role" do
      channel = unique_channel()
      founder = "Founder#{System.unique_integer([:positive])}"
      user = "VopUser#{System.unique_integer([:positive])}"

      start_registered_channel(channel, founder)

      insert(:access_list_entry,
        channel_name: channel,
        nickname: user,
        level: "vop",
        added_by: founder
      )

      {:ok, state} = Server.join(channel, user)
      assert {user, :voiced} in state.members
    end

    test "user with no access list entry gets :regular role" do
      channel = unique_channel()
      founder = "Founder#{System.unique_integer([:positive])}"
      user = "RegularUser#{System.unique_integer([:positive])}"

      start_registered_channel(channel, founder)

      {:ok, state} = Server.join(channel, user)
      assert {user, :regular} in state.members
    end

    test "user with 'founder' access level gets :owner role" do
      channel = unique_channel()
      founder = "Founder#{System.unique_integer([:positive])}"

      start_registered_channel(channel, founder)

      insert(:access_list_entry,
        channel_name: channel,
        nickname: founder,
        level: "founder",
        added_by: founder
      )

      {:ok, state} = Server.join(channel, founder)
      assert {founder, :owner} in state.members
    end

    test "user with 'sop' access level gets :owner role" do
      channel = unique_channel()
      founder = "Founder#{System.unique_integer([:positive])}"
      sop_user = "SopUser#{System.unique_integer([:positive])}"

      start_registered_channel(channel, founder)

      insert(:access_list_entry,
        channel_name: channel,
        nickname: sop_user,
        level: "sop",
        added_by: founder
      )

      {:ok, state} = Server.join(channel, sop_user)
      assert {sop_user, :owner} in state.members
    end

    test "first user in registered channel with no access gets :regular (not :operator)" do
      channel = unique_channel()
      founder = "Founder#{System.unique_integer([:positive])}"
      user = "FirstNoAccess#{System.unique_integer([:positive])}"

      start_registered_channel(channel, founder)

      # First user in a registered channel without access gets :regular
      {:ok, state} = Server.join(channel, user)
      assert {user, :regular} in state.members
    end
  end
end
