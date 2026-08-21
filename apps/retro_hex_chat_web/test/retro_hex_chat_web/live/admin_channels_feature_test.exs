defmodule RetroHexChatWeb.AdminChannelsFeatureTest do
  @moduledoc """
  Behaviour contract for the Admin Channels window.

  Migrated from the Admin Console's Channels tab when it was split into its own
  window: the assertions are unchanged, only the way the surface is opened and
  the element ids.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Server, Supervisor}
  alias RetroHexChat.Services.Queries
  alias RetroHexChatWeb.Components.UI.{AdminChannelsDialog, StartMenuApp}

  describe "Admin Channels panel" do
    test "renders filters, snapshots, info/create, destructive and ChanServ forms" do
      html =
        render_component(&AdminChannelsDialog.admin_channels_panel/1,
          id: "admin-channels-dialog",
          text: "*** Channel List (1 results) ***\n  #lobby",
          banlist_text: "*** No bans in #lobby",
          result: nil,
          search: "lob",
          info_channel: "#lobby",
          create_name: "#new",
          can_refresh: true,
          on_refresh: "admin_channels_refresh",
          on_info: "admin_channels_info",
          on_create: "admin_channels_create",
          on_delete: "admin_channels_delete",
          on_purge: "admin_channels_purge",
          on_cs_info: "admin_channels_cs_info",
          on_cs_drop: "admin_channels_cs_drop",
          on_cs_transfer: "admin_channels_cs_transfer",
          on_cs_access_list: "admin_channels_cs_access_list",
          on_cs_access_add: "admin_channels_cs_access_add",
          on_cs_access_del: "admin_channels_cs_access_del"
        )

      assert html =~ ~s(data-testid="admin-channels-panel")
      assert html =~ ~s(id="admin-channels-search-form")
      assert html =~ ~s(phx-submit="admin_channels_refresh")
      assert html =~ ~s(id="admin-channels-output")
      assert html =~ "#lobby"
      assert html =~ ~s(id="admin-channels-banlist")
      assert html =~ "No bans in #lobby"
      assert html =~ ~s(id="admin-channels-info-form")
      assert html =~ ~s(phx-submit="admin_channels_info")
      assert html =~ ~s(id="admin-channels-create-form")
      assert html =~ ~s(phx-submit="admin_channels_create")
      assert html =~ ~s(id="admin-channels-delete-form")
      assert html =~ ~s(phx-submit="admin_channels_delete")
      assert html =~ ~s(id="admin-channels-purge-form")
      assert html =~ ~s(phx-submit="admin_channels_purge")
      assert html =~ ~s(name="from")
      assert html =~ ~s(name="confirm")
      assert html =~ ~s(id="admin-channels-cs-info-form")
      assert html =~ ~s(phx-submit="admin_channels_cs_info")
      assert html =~ ~s(id="admin-channels-cs-access-list-form")
      assert html =~ ~s(id="admin-channels-cs-access-add-form")
      assert html =~ ~s(id="admin-channels-cs-access-del-form")
      assert html =~ ~s(id="admin-channels-cs-transfer-form")
      assert html =~ ~s(id="admin-channels-cs-drop-form")
      assert html =~ ~s(name="level")
      assert html =~ "Confirm delete"
      assert html =~ "Confirm purge"
      assert html =~ "ChanServ info"
      assert html =~ "Transfer founder"
      assert html =~ "Drop registration"
    end
  end

  describe "Admin Channels window" do
    test "admin can refresh, inspect and create channels", %{conn: conn} do
      channel = "#ac#{uid()}"
      member = "ACM#{uid()}"
      new_channel = "#anc#{uid()}"

      ensure_channel(channel)
      assert {:ok, _state} = Server.join(channel, member)

      view = connect_admin(conn)
      open_channels(view)

      html = render(view)

      # The window renders rows now, not the command's text block.
      assert html =~ ~s(data-testid="admin-channels-table")
      assert html =~ ~s(data-row-id="#{channel}")
      assert html =~ channel

      view
      |> form("#admin-channels-info-form", %{"channel" => channel})
      |> render_submit()

      html = render(view)

      assert html =~ "*** Channel: #{channel}"
      assert html =~ "Members"
      assert html =~ "No bans in #{channel}"

      view
      |> form("#admin-channels-create-form", %{"channel" => new_channel})
      |> render_submit()

      html = render(view)

      assert html =~ "Channel #{new_channel} created and registered."
      assert html =~ new_channel
    end

    test "admin can purge and delete channels with typed confirmation", %{conn: conn} do
      channel = "#dc#{uid()}"

      ensure_channel(channel)

      view = connect_admin(conn)
      open_channels(view)

      view
      |> form("#admin-channels-purge-form", %{
        "channel" => channel,
        "from" => "",
        "confirm" => channel
      })
      |> render_submit()

      html = render(view)

      assert html =~ "Purged 0 messages from #{channel}."

      view
      |> form("#admin-channels-delete-form", %{"channel" => channel, "confirm" => channel})
      |> render_submit()

      html = render(view)

      assert html =~ "Channel #{channel} has been deleted."
      assert Registry.lookup(channel) == {:error, :not_found}
    end

    test "a mistyped confirmation refuses the destructive action", %{conn: conn} do
      channel = "#mc#{uid()}"

      ensure_channel(channel)

      view = connect_admin(conn)
      open_channels(view)

      view
      |> form("#admin-channels-delete-form", %{"channel" => channel, "confirm" => "wrong"})
      |> render_submit()

      assert render(view) =~ "Type the channel name to confirm."
      assert {:ok, _pid} = Registry.lookup(channel)
    end

    test "admin can run ChanServ actions", %{conn: conn} do
      channel = "#cs#{uid()}"
      founder = "CSF#{uid()}" |> String.slice(0, 16)
      target = "CSA#{uid()}" |> String.slice(0, 16)
      new_founder = "CSN#{uid()}" |> String.slice(0, 16)

      assert {:ok, _channel} = Queries.insert_registered_channel(channel, founder)

      view = connect_admin(conn)
      open_channels(view)

      view
      |> form("#admin-channels-cs-info-form", %{"channel" => channel})
      |> render_submit()

      html = render(view)

      assert html =~ "[ChanServ] #{channel}"
      assert html =~ "Founder: #{founder}"

      view
      |> form("#admin-channels-cs-access-add-form", %{
        "channel" => channel,
        "level" => "aop",
        "nick" => target
      })
      |> render_submit()

      assert render(view) =~ "#{target} added to aop list of #{channel}"

      view
      |> form("#admin-channels-cs-access-list-form", %{"channel" => channel})
      |> render_submit()

      html = render(view)

      assert html =~ "Access List for #{channel}"
      assert html =~ target

      view
      |> form("#admin-channels-cs-access-del-form", %{
        "channel" => channel,
        "level" => "aop",
        "nick" => target
      })
      |> render_submit()

      assert render(view) =~ "#{target} removed from access list of #{channel}"

      view
      |> form("#admin-channels-cs-transfer-form", %{
        "channel" => channel,
        "nick" => new_founder
      })
      |> render_submit()

      assert render(view) =~ "Founder of #{channel} transferred to #{new_founder}"

      view
      |> form("#admin-channels-cs-drop-form", %{"channel" => channel, "confirm" => channel})
      |> render_submit()

      assert render(view) =~ "Channel #{channel} dropped by admin"
      assert Queries.find_registered_channel(channel) == nil
    end
  end

  describe "Admin Channels entry points and gating" do
    test "the Start menu's Admin group offers the window" do
      html =
        render_component(&StartMenuApp.start_menu_app/1,
          screen: :chat,
          windows: [],
          is_admin: true
        )

      assert html =~ ~s(data-testid="start-menu-item-open_admin_channels")
    end

    test "a non-admin sees the entry grayed, not hidden" do
      # The Start menu names what the app can do and grays what is out of
      # reach — asserting the row is simply absent would pass for the wrong
      # reason now that the chat's File menu no longer carries it at all.
      doc =
        render_component(&StartMenuApp.start_menu_app/1, screen: :chat, windows: [])
        |> Floki.parse_document!()

      row = Floki.find(doc, ~s([data-testid="start-menu-item-open_admin_channels"]))

      assert row != []
      assert Floki.attribute(row, "disabled") != []
    end

    test "opening mounts a managed window and closing unmounts it", %{conn: conn} do
      view = connect_admin(conn)

      refute has_element?(view, ~s([data-window-id="admin-channels"]))

      open_channels(view)

      assert has_element?(view, ~s([data-window-id="admin-channels"][data-window-managed="true"]))
      assert_push_event(view, "window_command", %{action: "open", id: "admin-channels"})

      render_hook(view, "window_closed", %{"id" => "admin-channels"})

      refute has_element?(view, ~s([data-window-id="admin-channels"]))
    end

    test "a forged window_open renders nothing for a non-admin", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Plain#{uid()}"), "/chat")

      render_hook(view, "window_open", %{"id" => "admin-channels"})

      refute has_element?(view, ~s([data-testid="admin-channels-panel"]))
    end
  end

  defp connect_admin(conn) do
    {:ok, view, _html} = live(chat_conn(conn, "TestAdmin", pre_identified: true), "/chat")
    view
  end

  defp open_channels(view) do
    render_click(view, "toolbar_action", %{"action" => "open_admin_channels"})
    render(view)
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} ->
        :ok

      {:error, :not_found} ->
        case Supervisor.start_child(name) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
        end
    end
  end
end
