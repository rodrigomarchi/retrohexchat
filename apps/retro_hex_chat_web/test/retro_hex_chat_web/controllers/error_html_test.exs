defmodule RetroHexChatWeb.ErrorHTMLTest do
  use RetroHexChatWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html as a blue screen with the 404 exception code" do
    html = render_to_string(RetroHexChatWeb.ErrorHTML, "404", "html", [])

    assert html =~ "<!DOCTYPE html>"
    assert html =~ ~s(data-testid="bsod")
    assert html =~ "A fatal exception 0x194 has occurred"
    # The whole screen links home, so the page works without JS.
    assert html =~ ~s(<a href="/" class="bsod")
  end

  test "renders 500.html as a blue screen with the 500 exception code" do
    html = render_to_string(RetroHexChatWeb.ErrorHTML, "500", "html", [])

    assert html =~ "A fatal exception 0x1F4 has occurred"
  end

  test "any other status falls back to a generic blue screen" do
    html = render_to_string(RetroHexChatWeb.ErrorHTML, "403", "html", [])

    assert html =~ "A fatal exception 0x193 has occurred"
    assert html =~ "Forbidden"
  end

  test "reports the status to Google only when there is a measurement id" do
    refute render_to_string(RetroHexChatWeb.ErrorHTML, "404", "html", []) =~ "page_error"

    Application.put_env(:retro_hex_chat_web, :ga_measurement_id, "G-TEST")
    on_exit(fn -> Application.delete_env(:retro_hex_chat_web, :ga_measurement_id) end)

    html = render_to_string(RetroHexChatWeb.ErrorHTML, "410", "html", [])

    assert html =~ "page_error"
    assert html =~ ~s(data-id="G-TEST" data-status="410")
  end
end
