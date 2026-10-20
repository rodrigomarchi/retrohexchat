# A message that arrives is matched at once; the timeout only bounds how long a
# missing one is waited for, which a loaded machine running many partitions
# stretches well past the 100ms default.
ExUnit.start(exclude: [:liveview_feature], assert_receive_timeout: 1_000)
Ecto.Adapters.SQL.Sandbox.mode(RetroHexChat.Repo, :manual)
