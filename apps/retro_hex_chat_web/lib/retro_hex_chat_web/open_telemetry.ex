defmodule RetroHexChatWeb.OpenTelemetry do
  @moduledoc false

  def setup do
    OpentelemetryBandit.setup()
    OpentelemetryPhoenix.setup(adapter: :bandit)
    OpentelemetryEcto.setup([:retro_hex_chat, :repo], db_statement: :enabled)
    :ok = OpentelemetryLoggerMetadata.setup()

    :ok
  end
end
