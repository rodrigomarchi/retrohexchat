defmodule RetroHexChatWeb.ErrorHTML do
  @moduledoc """
  Renders HTML errors as retro blue screens.

  Every status code gets the Win98 fatal-exception treatment; 404 and 500
  carry dedicated copy, anything else falls back to a generic screen built
  from the status message. Pages render without a layout (see
  config/config.exs), so each one is a complete document that links the
  compiled stylesheet — with styles unavailable it degrades to readable text.

  The whole screen is a link back to `/`; a keydown listener adds the
  classic "press any key" behaviour.
  """
  use RetroHexChatWeb, :html

  @spec render(String.t(), map()) :: Phoenix.LiveView.Rendered.t()
  def render("404.html", _assigns) do
    bsod(%{
      code: "0x194",
      module: "HEXGRID(01)",
      cause:
        "The page you are looking for has been unloaded from memory, " <>
          "moved to another channel, or never existed at all.",
      bullets: [
        "Press any key to return to RetroHexChat.",
        "If you typed the address by hand, current technology cannot rule out a typo."
      ]
    })
  end

  def render("500.html", _assigns) do
    bsod(%{
      code: "0x1F4",
      module: "RETROHEX(01)",
      cause: "The current request has been terminated to protect your desktop.",
      bullets: [
        "Press any key to return to RetroHexChat.",
        "Our operators have been notified and are already blaming each other."
      ]
    })
  end

  def render(template, _assigns) do
    bsod(%{
      code: hex_code(template),
      module: "RETROHEX(01)",
      cause:
        Phoenix.Controller.status_message_from_template(template) <>
          ". The current request has been terminated.",
      bullets: ["Press any key to return to RetroHexChat."]
    })
  end

  attr :code, :string, required: true
  attr :module, :string, required: true
  attr :cause, :string, required: true
  attr :bullets, :list, required: true

  defp bsod(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="robots" content="noindex, nofollow, noarchive" />
        <title>RetroHexChat</title>
        <link rel="stylesheet" href={~p"/assets/css/retrohex.css"} />
      </head>
      <body>
        <a href="/" class="bsod" data-testid="bsod">
          <div class="bsod__panel">
            <span class="bsod__chip">RetroHexChat</span>
            <p class="bsod__text">
              A fatal exception {@code} has occurred at 0028:C0044E2E in module {@module}. {@cause}
            </p>
            <ul class="bsod__list">
              <li :for={bullet <- @bullets}>* {bullet}</li>
            </ul>
            <p class="bsod__continue">
              Press any key to continue <span class="bsod__cursor">_</span>
            </p>
          </div>
        </a>
        <script>
          window.addEventListener("keydown", () => {
            window.location.href = "/";
          });
        </script>
      </body>
    </html>
    """
  end

  # "404.html" -> "0x194"; non-numeric templates get a null pointer.
  @spec hex_code(String.t()) :: String.t()
  defp hex_code(template) do
    case Integer.parse(template) do
      {status, _rest} -> "0x" <> Integer.to_string(status, 16)
      :error -> "0x0"
    end
  end
end
