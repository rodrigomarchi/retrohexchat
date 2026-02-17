defmodule RetroHexChatWeb.Components.ChatContextMenuTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.ChatContextMenu

  @nick_menu %{
    visible: true,
    type: :nick,
    x: 100,
    y: 200,
    target_nick: "alice",
    target_url: nil,
    target_channel: nil,
    target_message: nil,
    has_selection: false,
    is_target_registered: false
  }

  describe "P2P items in nick context menu" do
    @tag :unit
    test "renders P2P items when viewer_is_identified is true and target is registered" do
      html =
        render_component(&ChatContextMenu.chat_context_menu/1,
          menu: %{@nick_menu | is_target_registered: true},
          viewer_nick: "bob",
          viewer_is_identified: true,
          is_target_registered: true,
          is_target_self: false,
          viewer_is_op: false,
          is_target_ignored: false
        )

      assert html =~ ~s(data-testid="ctx-chat-p2p")
      assert html =~ ~s(data-testid="ctx-chat-call")
      assert html =~ ~s(data-testid="ctx-chat-video-call")
      assert html =~ ~s(data-testid="ctx-chat-sendfile")
      assert html =~ "Sessão P2P"
      assert html =~ "Chamada de Áudio"
      assert html =~ "Chamada de Vídeo"
      assert html =~ "Enviar Arquivo"
      assert html =~ ~s(phx-click="ctx_chat_p2p")
    end

    @tag :unit
    test "does not render P2P items for guest user (viewer_is_identified false)" do
      html =
        render_component(&ChatContextMenu.chat_context_menu/1,
          menu: @nick_menu,
          viewer_nick: "guest",
          viewer_is_identified: false,
          is_target_registered: false,
          is_target_self: false,
          viewer_is_op: false,
          is_target_ignored: false
        )

      refute html =~ ~s(data-testid="ctx-chat-p2p")
      refute html =~ ~s(data-testid="ctx-chat-call")
      refute html =~ "Sessão P2P"
    end

    @tag :unit
    test "P2P items disabled with tooltip when target is not registered" do
      html =
        render_component(&ChatContextMenu.chat_context_menu/1,
          menu: @nick_menu,
          viewer_nick: "bob",
          viewer_is_identified: true,
          is_target_registered: false,
          is_target_self: false,
          viewer_is_op: false,
          is_target_ignored: false
        )

      assert html =~ ~s(data-testid="ctx-chat-p2p")
      assert html =~ ~r/disabled[^>]*ctx-chat-p2p/
      assert html =~ "Usuário não registrado"
      refute html =~ ~s(phx-click="ctx_chat_p2p")
    end

    @tag :unit
    test "P2P items disabled without tooltip when target is self" do
      html =
        render_component(&ChatContextMenu.chat_context_menu/1,
          menu: %{@nick_menu | target_nick: "bob", is_target_registered: true},
          viewer_nick: "bob",
          viewer_is_identified: true,
          is_target_registered: true,
          is_target_self: true,
          viewer_is_op: false,
          is_target_ignored: false
        )

      assert html =~ ~s(data-testid="ctx-chat-p2p")
      assert html =~ ~r/disabled[^>]*ctx-chat-p2p/
      refute html =~ "Usuário não registrado"
      refute html =~ ~s(phx-click="ctx_chat_p2p")
    end
  end
end
