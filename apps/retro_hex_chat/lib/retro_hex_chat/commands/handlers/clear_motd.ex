defmodule RetroHexChat.Commands.Handlers.ClearMotd do
  @moduledoc "Handler for /clearmotd — admin clears the MOTD."
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Services.Motd

  use RetroHexChat.Commands.Handler,
    name: "clearmotd",
    category: :advanced,
    syntax: "/clearmotd",
    summary:
      dgettext(
        "commands",
        "Remove the server's Message of the Day so new users won't see any MOTD. Admin only."
      ),
    description:
      dgettext(
        "commands",
        "Remove the server's Message of the Day so new users won't see any MOTD. Admin only."
      ),
    examples: ["/clearmotd"]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, %{is_admin: false}) do
    {:error, dgettext("commands", "Permission denied: you must be a server administrator.")}
  end

  def execute(_args, %{is_admin: true, nickname: nickname}) do
    Motd.clear(nickname)
    {:ok, :system, %{content: dgettext("commands", "MOTD has been cleared.")}}
  end
end
