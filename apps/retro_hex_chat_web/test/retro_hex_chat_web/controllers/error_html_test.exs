defmodule RetroHexChatWeb.ErrorHTMLTest do
  use RetroHexChatWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html as a blue screen with the 404 exception code" do
    html = render_to_string(RetroHexChatWeb.ErrorHTML, "404", "html", [])

    assert html =~ "<!DOCTYPE html>"
    assert html =~ ~s(data-testid="bsod")
    assert html =~ "A fatal exception 0x194 has occurred"
    assert html =~ "never existed at all"
    assert html =~ "Press any key to continue"
    # The whole screen links home, so the page works without JS.
    assert html =~ ~s(<a href="/" class="bsod")
  end

  test "renders 500.html as a blue screen with the 500 exception code" do
    html = render_to_string(RetroHexChatWeb.ErrorHTML, "500", "html", [])

    assert html =~ "A fatal exception 0x1F4 has occurred"
    assert html =~ "terminated to protect your desktop"
    assert html =~ ~s(data-testid="bsod")
  end

  test "any other status falls back to a generic blue screen" do
    html = render_to_string(RetroHexChatWeb.ErrorHTML, "403", "html", [])

    assert html =~ "A fatal exception 0x193 has occurred"
    assert html =~ "Forbidden"
    assert html =~ ~s(data-testid="bsod")
  end
end
