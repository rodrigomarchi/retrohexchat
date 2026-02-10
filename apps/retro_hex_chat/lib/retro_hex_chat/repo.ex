defmodule RetroHexChat.Repo do
  use Ecto.Repo,
    otp_app: :retro_hex_chat,
    adapter: Ecto.Adapters.Postgres
end
