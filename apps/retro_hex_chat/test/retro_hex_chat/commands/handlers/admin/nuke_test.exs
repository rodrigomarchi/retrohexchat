defmodule RetroHexChat.Commands.Handlers.Admin.NukeTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Admin
  alias RetroHexChat.Admin.{AdminRole, AuditLogs}
  alias RetroHexChat.Chat.Message
  alias RetroHexChat.Chat.PrivateMessage
  alias RetroHexChat.Commands.Handlers.Admin.Nuke
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick

  @admin_context %{
    nickname: "NukeAdmin",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: true,
    operator_in: [],
    half_operator_in: [],
    is_admin: true,
    is_server_operator: false
  }

  defp seed_data do
    # Insert a registered nick via registration_changeset (handles password hashing)
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{
        nickname: "NukeTestU",
        password: "password123"
      })
      |> Repo.insert()

    # Insert messages
    {:ok, _msg} =
      %Message{}
      |> Message.changeset(%{
        channel_name: "#test",
        author_nickname: "NukeTestU",
        content: "hello world"
      })
      |> Repo.insert()

    # Insert private messages
    {:ok, _pm} =
      %PrivateMessage{}
      |> PrivateMessage.changeset(%{
        sender_nickname: "NukeTestU",
        recipient_nickname: "NukeAdmin",
        content: "private hello"
      })
      |> Repo.insert()

    # Insert an admin role to verify preservation
    {:ok, _role} =
      %AdminRole{}
      |> AdminRole.changeset(%{
        nickname: "NukeAdmin",
        role: "admin",
        granted_by: "root"
      })
      |> Repo.insert()

    nick
  end

  describe "preview mode" do
    test "returns record counts without deleting" do
      seed_data()

      assert {:ok, :system, %{content: text}} = Nuke.execute([], @admin_context)
      assert text =~ "NUKE PREVIEW"
      assert text =~ "messages:"
      assert text =~ "registered_nicks:"
      assert text =~ "--confirm"

      # Data should still exist
      assert Repo.aggregate(Message, :count) > 0
      assert Repo.aggregate(RegisteredNick, :count) > 0
    end

    test "shows clean message when nothing to delete" do
      assert {:ok, :system, %{content: text}} = Nuke.execute([], @admin_context)
      assert text =~ "Nothing to delete"
    end
  end

  describe "execute mode" do
    test "deletes all data with --confirm" do
      seed_data()

      assert {:ok, :system, %{content: text}} = Nuke.execute(["--confirm"], @admin_context)
      assert text =~ "SYSTEM NUKED"
      assert text =~ "deleted"

      # Verify data is gone
      assert Repo.aggregate(Message, :count) == 0
      assert Repo.aggregate(PrivateMessage, :count) == 0
      assert Repo.aggregate(RegisteredNick, :count) == 0
    end

    test "preserves admin_roles" do
      seed_data()

      Nuke.execute(["--confirm"], @admin_context)

      assert Repo.aggregate(AdminRole, :count) > 0
    end

    test "preserves audit_logs" do
      seed_data()
      AuditLogs.log("NukeAdmin", "test.action")
      before_count = Repo.aggregate(RetroHexChat.Admin.AuditLog, :count)

      Nuke.execute(["--confirm"], @admin_context)

      # Audit log count should be >= before (nuke itself adds a log entry)
      assert Repo.aggregate(RetroHexChat.Admin.AuditLog, :count) >= before_count
    end
  end

  describe "error handling" do
    test "returns usage error for invalid args" do
      assert {:error, msg} = Nuke.execute(["--invalid"], @admin_context)
      assert msg =~ "Usage:"
    end
  end

  describe "Admin facade" do
    test "nuke_preview returns counts" do
      seed_data()

      {:ok, counts} = Admin.nuke_preview("NukeAdmin")
      assert is_list(counts)
      assert Enum.any?(counts, fn {name, count} -> name == "messages" and count > 0 end)
      assert Enum.any?(counts, fn {name, count} -> name == "registered_nicks" and count > 0 end)
    end

    test "nuke_system returns deleted counts" do
      seed_data()

      {:ok, summary} = Admin.nuke_system("NukeAdmin")
      assert is_list(summary)

      messages_deleted = Enum.find_value(summary, fn {n, c} -> if n == "messages", do: c end)
      assert messages_deleted > 0
    end
  end
end
