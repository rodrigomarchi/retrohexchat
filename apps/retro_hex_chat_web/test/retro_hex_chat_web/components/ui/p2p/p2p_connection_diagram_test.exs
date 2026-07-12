defmodule RetroHexChatWeb.Components.UI.P2PConnectionDiagramTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.P2PConnectionDiagram

  @moduletag :unit

  @emoji_regression ~r/[🖥🗣🕐🎨👆📄🔍📹🎤📞✓✗]/u

  defp render_diagram(assigns) do
    render_component(
      &p2p_connection_diagram/1,
      Map.merge(
        %{
          nickname: "neo",
          peer_nick: "trinity",
          peer_online: true,
          session_status: "connected",
          webrtc_state: "Connected",
          local_info: %{
            browser: "Chrome",
            os: "macOS",
            screen: "1440x900",
            language: "pt-BR",
            timezone: "America/Sao_Paulo",
            cores: 8,
            color_depth: 24,
            touch: true
          },
          peer_info: %{
            browser: "Firefox",
            os: "Linux",
            screen: "1920x1080",
            language: "en-US",
            timezone: "UTC",
            cores: 12,
            color_depth: 24,
            touch: true
          }
        },
        assigns
      )
    )
  end

  test "whois and badge iconography render through SVG instead of emoji" do
    html =
      render_diagram(%{
        call: %{type: "video", duration: "00:00:03", quality_label: "Good"}
      })

    refute html =~ @emoji_regression
    assert html =~ ~s(class="p2p-diagram__whois-svg")
    assert html =~ "Video Call"
  end

  test "file transfer states do not reintroduce emoji badges" do
    html =
      render_diagram(%{
        file_transfer: %{
          status: "transferring",
          sender_nick: "neo",
          percent: 42,
          file_name: "report.pdf",
          speed: "2 MB/s"
        }
      })

    refute html =~ @emoji_regression
    assert html =~ "report.pdf"
    assert html =~ "42%"
  end
end
