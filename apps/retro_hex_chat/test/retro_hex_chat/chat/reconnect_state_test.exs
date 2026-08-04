defmodule RetroHexChat.Chat.ReconnectStateTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Chat.ReconnectState
  alias RetroHexChat.Services.Queries

  describe "normalize/1" do
    @tag :unit
    test "keeps only valid reconnect fields and deduplicates lists" do
      snapshot =
        ReconnectState.normalize(%{
          "nickname" => "Rod",
          "channels" => ["#lobby", "bad", "#lobby", " #trimmed"],
          "active_channel" => "#lobby",
          "active_pm" => "Alice",
          "open_pm_tabs" => ["Alice", "", "Alice", " Bob "],
          "tab_order" => [
            %{"type" => "channel", "label" => "#lobby"},
            %{"type" => "bad", "label" => "#ignored"},
            %{"type" => "pm", "label" => "Alice"},
            %{"type" => "pm", "label" => ""}
          ],
          "welcomed_channels" => ["#lobby", "#dev", "#lobby"]
        })

      assert snapshot == %{
               nickname: "Rod",
               channels: ["#lobby"],
               active_channel: "#lobby",
               active_pm: "Alice",
               open_pm_tabs: ["Alice"],
               tab_order: [
                 %{type: "channel", label: "#lobby"},
                 %{type: "pm", label: "Alice"}
               ],
               welcomed_channels: ["#lobby", "#dev"]
             }
    end

    @tag :unit
    test "drops active targets that are not part of the restored snapshot" do
      snapshot =
        ReconnectState.normalize(%{
          channels: ["#lobby"],
          active_channel: "#missing",
          open_pm_tabs: ["Alice"],
          active_pm: "Bob"
        })

      assert snapshot.active_channel == nil
      assert snapshot.active_pm == nil
    end

    @tag :unit
    test "caps large snapshots" do
      snapshot =
        ReconnectState.normalize(%{
          channels: Enum.map(1..60, &"#c#{&1}"),
          open_pm_tabs: Enum.map(1..30, &"User#{&1}"),
          tab_order: Enum.map(1..120, &%{type: "channel", label: "#c#{&1}"})
        })

      assert length(snapshot.channels) == 50
      assert length(snapshot.open_pm_tabs) == 20
      assert length(snapshot.tab_order) == 100
    end

    @tag :unit
    test "returns an empty snapshot for malformed values" do
      assert ReconnectState.normalize(nil) == ReconnectState.new()

      assert ReconnectState.normalize(%{
               channels: "not a list",
               open_pm_tabs: %{},
               tab_order: "bad"
             }) == ReconnectState.new()
    end
  end

  describe "save/2, load/1 and delete/1" do
    @tag :integration
    test "round-trips a normalized snapshot through the database" do
      nick = "ReconnUser1"
      insert_registered_nick(nick)

      assert :ok =
               ReconnectState.save(nick, %{
                 channels: ["#lobby", "#dev"],
                 active_channel: "#dev",
                 open_pm_tabs: ["Alice"],
                 active_pm: "Alice",
                 tab_order: [%{type: "channel", label: "#dev"}, %{type: "pm", label: "Alice"}],
                 welcomed_channels: ["#lobby"]
               })

      assert {:ok, loaded} = ReconnectState.load(nick)

      assert loaded == %{
               nickname: nick,
               channels: ["#lobby", "#dev"],
               active_channel: "#dev",
               active_pm: "Alice",
               open_pm_tabs: ["Alice"],
               tab_order: [%{type: "channel", label: "#dev"}, %{type: "pm", label: "Alice"}],
               welcomed_channels: ["#lobby"]
             }
    end

    @tag :integration
    test "overwrites existing state and deletes idempotently" do
      nick = "ReconnUser2"
      insert_registered_nick(nick)

      assert :ok = ReconnectState.save(nick, %{channels: ["#old"], active_channel: "#old"})
      assert :ok = ReconnectState.save(nick, %{channels: ["#new"], active_channel: "#new"})

      assert {:ok, loaded} = ReconnectState.load(nick)
      assert loaded.channels == ["#new"]
      assert loaded.active_channel == "#new"

      assert :ok = ReconnectState.delete(nick)
      assert :ok = ReconnectState.delete(nick)
      assert {:error, :not_found} = ReconnectState.load(nick)
    end
  end

  defp insert_registered_nick(nickname) do
    {:ok, _} = Queries.insert_registered_nick(nickname, "password123")
  end
end
