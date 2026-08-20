defmodule RetroHexChatWeb.FaroMetaTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChatWeb.BuildInfo

  setup do
    ensure_channel("#lobby")
    :ok
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  describe "Faro RUM meta tags in the chat layout" do
    test "renders the collector url and app version metas", %{conn: conn} do
      nick = "Faro#{uid()}"
      html = conn |> chat_conn(nick) |> get("/chat") |> html_response(200)

      assert html =~ ~s(<meta name="faro-collector-url" content="/faro/collect")
      assert html =~ ~s(<meta name="faro-app-version" content="#{BuildInfo.version()}")
      assert html =~ ~s(<meta name="faro-enabled")
    end

    test "reflects the faro_enabled config in the enabled meta", %{conn: conn} do
      previous = Application.get_env(:retro_hex_chat_web, :faro_enabled, false)
      Application.put_env(:retro_hex_chat_web, :faro_enabled, true)
      on_exit(fn -> Application.put_env(:retro_hex_chat_web, :faro_enabled, previous) end)

      nick = "Faro#{uid()}"
      html = conn |> chat_conn(nick) |> get("/chat") |> html_response(200)

      assert html =~ ~s(<meta name="faro-enabled" content="true")
    end
  end
end
