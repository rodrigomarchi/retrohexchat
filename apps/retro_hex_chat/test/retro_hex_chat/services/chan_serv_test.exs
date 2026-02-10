defmodule RetroHexChat.Services.ChanServTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Services.ChanServ
  alias RetroHexChat.Services.NickServ

  setup do
    nick_server = :"nickserv_cs_#{System.unique_integer([:positive])}"
    {:ok, _} = NickServ.start_link(name: nick_server)

    cs_server = :"chanserv_#{System.unique_integer([:positive])}"
    {:ok, _} = ChanServ.start_link(name: cs_server, nick_serv: nick_server)

    %{server: cs_server, nick_server: nick_server}
  end

  defp register_and_identify(nickname, password, nick_server) do
    {:ok, _} = NickServ.register(nickname, password, nick_server)
  end

  describe "register/3" do
    test "creates registered channel and founder access entry", ctx do
      register_and_identify("CsFounder", "pass123", ctx.nick_server)

      assert {:ok, msg} = ChanServ.register("#mychan", "CsFounder", ctx.server)
      assert msg =~ "#mychan"
      assert msg =~ "registered"

      assert {:ok, "founder"} = ChanServ.check_access("#mychan", "CsFounder", ctx.server)
    end

    test "returns error for duplicate registration", ctx do
      register_and_identify("CsDupe", "pass123", ctx.nick_server)

      {:ok, _} = ChanServ.register("#dupechan", "CsDupe", ctx.server)
      assert {:error, msg} = ChanServ.register("#dupechan", "CsDupe", ctx.server)
      assert is_binary(msg)
    end

    test "returns error when user not identified", ctx do
      assert {:error, msg} = ChanServ.register("#nochan", "NotIdentified", ctx.server)
      assert msg =~ "identified"
    end
  end

  describe "drop/3" do
    test "deletes channel if requester is founder", ctx do
      register_and_identify("CsDropF", "pass123", ctx.nick_server)
      {:ok, _} = ChanServ.register("#dropchan", "CsDropF", ctx.server)

      assert {:ok, msg} = ChanServ.drop("#dropchan", "CsDropF", ctx.server)
      assert msg =~ "dropped"
    end

    test "returns error if requester is not founder", ctx do
      register_and_identify("CsDropF2", "pass123", ctx.nick_server)
      register_and_identify("CsNotF", "pass123", ctx.nick_server)
      {:ok, _} = ChanServ.register("#dropchan2", "CsDropF2", ctx.server)

      assert {:error, msg} = ChanServ.drop("#dropchan2", "CsNotF", ctx.server)
      assert msg =~ "founder"
    end

    test "returns error for unregistered channel", ctx do
      register_and_identify("CsDropU", "pass123", ctx.nick_server)

      assert {:error, msg} = ChanServ.drop("#nosuch", "CsDropU", ctx.server)
      assert msg =~ "not registered"
    end
  end

  describe "drop/3 cascade cleanup" do
    test "dropping channel removes access entries and bans", ctx do
      register_and_identify("CsCascF", "pass123", ctx.nick_server)
      register_and_identify("CsCascU", "pass123", ctx.nick_server)
      {:ok, _} = ChanServ.register("#cascchan", "CsCascF", ctx.server)

      # Add access entries
      {:ok, _} =
        ChanServ.manage_access("#cascchan", :add, "sop", "CsCascU", "CsCascF", ctx.server)

      # Verify access exists
      assert {:ok, "sop"} = ChanServ.check_access("#cascchan", "CsCascU", ctx.server)

      # Drop the channel — should cascade cleanup
      assert {:ok, _} = ChanServ.drop("#cascchan", "CsCascF", ctx.server)

      # Channel should no longer exist
      assert {:error, msg} = ChanServ.info("#cascchan", ctx.server)
      assert msg =~ "not registered"
    end
  end

  describe "info/2" do
    test "returns channel info map", ctx do
      register_and_identify("CsInfoF", "pass123", ctx.nick_server)
      {:ok, _} = ChanServ.register("#infochan", "CsInfoF", ctx.server)

      assert {:ok, info} = ChanServ.info("#infochan", ctx.server)
      assert info.name == "#infochan"
      assert info.founder == "CsInfoF"
      assert info.registered_at != nil
    end

    test "returns error for unregistered channel", ctx do
      assert {:error, msg} = ChanServ.info("#nosuch", ctx.server)
      assert msg =~ "not registered"
    end
  end

  describe "check_access/2" do
    test "returns access level for user", ctx do
      register_and_identify("CsAccessF", "pass123", ctx.nick_server)
      {:ok, _} = ChanServ.register("#accesschan", "CsAccessF", ctx.server)

      assert {:ok, "founder"} = ChanServ.check_access("#accesschan", "CsAccessF", ctx.server)
    end

    test "returns nil for user without access", ctx do
      register_and_identify("CsAccessF2", "pass123", ctx.nick_server)
      {:ok, _} = ChanServ.register("#accesschan2", "CsAccessF2", ctx.server)

      assert {:ok, nil} = ChanServ.check_access("#accesschan2", "nobody", ctx.server)
    end
  end

  describe "manage_access/6 hierarchy enforcement" do
    setup ctx do
      register_and_identify("Founder", "pass123", ctx.nick_server)
      {:ok, _} = ChanServ.register("#hierarchy", "Founder", ctx.server)

      register_and_identify("SopUser", "pass123", ctx.nick_server)
      register_and_identify("AopUser", "pass123", ctx.nick_server)
      register_and_identify("VopUser", "pass123", ctx.nick_server)
      register_and_identify("Target", "pass123", ctx.nick_server)

      {:ok, _} =
        ChanServ.manage_access("#hierarchy", :add, "sop", "SopUser", "Founder", ctx.server)

      {:ok, _} =
        ChanServ.manage_access("#hierarchy", :add, "aop", "AopUser", "Founder", ctx.server)

      {:ok, _} =
        ChanServ.manage_access("#hierarchy", :add, "vop", "VopUser", "Founder", ctx.server)

      :ok
    end

    test "founder can add sop", ctx do
      assert {:ok, _} =
               ChanServ.manage_access("#hierarchy", :add, "sop", "Target", "Founder", ctx.server)
    end

    test "founder can add aop", ctx do
      assert {:ok, _} =
               ChanServ.manage_access("#hierarchy", :add, "aop", "Target", "Founder", ctx.server)
    end

    test "founder can add vop", ctx do
      assert {:ok, _} =
               ChanServ.manage_access("#hierarchy", :add, "vop", "Target", "Founder", ctx.server)
    end

    test "sop can add aop", ctx do
      assert {:ok, _} =
               ChanServ.manage_access("#hierarchy", :add, "aop", "Target", "SopUser", ctx.server)
    end

    test "sop can add vop", ctx do
      assert {:ok, _} =
               ChanServ.manage_access("#hierarchy", :add, "vop", "Target", "SopUser", ctx.server)
    end

    test "sop cannot add sop", ctx do
      assert {:error, msg} =
               ChanServ.manage_access("#hierarchy", :add, "sop", "Target", "SopUser", ctx.server)

      assert msg =~ "permission"
    end

    test "aop can add vop", ctx do
      assert {:ok, _} =
               ChanServ.manage_access("#hierarchy", :add, "vop", "Target", "AopUser", ctx.server)
    end

    test "aop cannot add aop", ctx do
      assert {:error, msg} =
               ChanServ.manage_access("#hierarchy", :add, "aop", "Target", "AopUser", ctx.server)

      assert msg =~ "permission"
    end

    test "aop cannot add sop", ctx do
      assert {:error, msg} =
               ChanServ.manage_access("#hierarchy", :add, "sop", "Target", "AopUser", ctx.server)

      assert msg =~ "permission"
    end

    test "vop cannot manage access", ctx do
      assert {:error, msg} =
               ChanServ.manage_access("#hierarchy", :add, "vop", "Target", "VopUser", ctx.server)

      assert msg =~ "permission"
    end

    test "founder can remove sop", ctx do
      assert {:ok, _} =
               ChanServ.manage_access(
                 "#hierarchy",
                 :remove,
                 "sop",
                 "SopUser",
                 "Founder",
                 ctx.server
               )
    end

    test "sop can remove aop", ctx do
      assert {:ok, _} =
               ChanServ.manage_access(
                 "#hierarchy",
                 :remove,
                 "aop",
                 "AopUser",
                 "SopUser",
                 ctx.server
               )
    end

    test "aop cannot remove aop", ctx do
      register_and_identify("AopUser2", "pass123", ctx.nick_server)

      {:ok, _} =
        ChanServ.manage_access("#hierarchy", :add, "aop", "AopUser2", "Founder", ctx.server)

      assert {:error, msg} =
               ChanServ.manage_access(
                 "#hierarchy",
                 :remove,
                 "aop",
                 "AopUser2",
                 "AopUser",
                 ctx.server
               )

      assert msg =~ "permission"
    end

    test "returns error when requester not identified", ctx do
      assert {:error, msg} =
               ChanServ.manage_access(
                 "#hierarchy",
                 :add,
                 "vop",
                 "Target",
                 "NotIdentified",
                 ctx.server
               )

      assert msg =~ "identified"
    end

    test "manage_access with invalid level from low-rank user returns permission error", ctx do
      # VopUser (rank 1) cannot add any level since all valid levels have rank >= 1
      assert {:error, msg} =
               ChanServ.manage_access(
                 "#hierarchy",
                 :add,
                 "founder",
                 "Target",
                 "VopUser",
                 ctx.server
               )

      assert msg =~ "permission"
    end

    test "remove non-existent access entry returns error", ctx do
      assert {:error, msg} =
               ChanServ.manage_access(
                 "#hierarchy",
                 :remove,
                 "vop",
                 "NonExistent",
                 "Founder",
                 ctx.server
               )

      assert msg =~ "not found"
    end
  end
end
