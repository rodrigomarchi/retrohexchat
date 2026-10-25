defmodule RetroHexChatWeb.CallLive.Recovery do
  @moduledoc """
  The conference's connection as this page shows it: the browser's reports of
  the peer connection's state and of its recovery attempts, turned into the
  call's status, the sentence on the status bar, and the telemetry a recovery
  transition emits.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Calls.Events, as: CallEvents
  alias RetroHexChatWeb.App.GroupCallShape
  alias RetroHexChatWeb.CallLive.CallAssign
  alias RetroHexChatWeb.Live.Surface

  @doc "Takes in the browser's peer-connection state: connected clears the warnings and reports the recovery, a failure or disconnect says so."
  @spec apply_connection_state(Socket.t(), term()) :: Socket.t()
  def apply_connection_state(socket, state) do
    case to_string(state) do
      "connected" ->
        CallEvents.emit_recovery_transition(:group_call, :connected, "connection_state", %{
          manual_retry: false,
          trigger: "connection_state"
        })

        CallAssign.update(socket, fn call ->
          call
          |> Map.put(:connection_state, state)
          |> Map.put(:status, :connected)
          |> Map.put(:warning, nil)
          |> Map.put(:error, nil)
        end)

      "disconnected" ->
        message =
          dgettext("group_call", "Group call media connection interrupted. Trying to recover.")

        CallEvents.emit_recovery_transition(
          :group_call,
          :reconnecting,
          "connection_disconnected",
          %{
            manual_retry: false,
            trigger: "connection_state"
          }
        )

        CallAssign.update(socket, fn call ->
          call
          |> Map.put(:connection_state, state)
          |> Map.put(:status, :reconnecting)
          |> Map.put(:warning, message)
          |> Map.put(:error, nil)
        end)

      "failed" ->
        message =
          dgettext(
            "group_call",
            "Group call media connection failed. Retry the media connection."
          )

        CallEvents.emit_recovery_transition(:group_call, :failed, "connection_failed", %{
          manual_retry: true,
          trigger: "connection_state"
        })

        CallEvents.emit_client_error(:group_call, "connection_failed", %{
          phase: "connection_state"
        })

        socket =
          CallAssign.update(socket, fn call ->
            call
            |> Map.put(:connection_state, state)
            |> Map.put(:status, :error)
            |> Map.put(:error, message)
            |> Map.put(:warning, nil)
            |> Map.put(:recovery, %{
              GroupCallShape.empty_recovery()
              | state: :failed,
                manual_retry: true,
                message: message
            })
          end)

        Surface.error(socket, message)

      _other ->
        CallAssign.update(socket, &Map.put(&1, :connection_state, state))
    end
  end

  @doc "Marks the call negotiating, unless its connection is already up."
  @spec put_negotiating_status(map()) :: map()
  def put_negotiating_status(%{connection_state: "connected"} = call), do: call

  def put_negotiating_status(call), do: Map.put(call, :status, :negotiating)

  @doc "A stats report from a connected peer connection marks the call connected and clears its warnings."
  @spec apply_stats_connection_state(map(), map()) :: map()
  def apply_stats_connection_state(call, %{summary: %{connection_state: "connected"}}) do
    call
    |> Map.put(:connection_state, "connected")
    |> Map.put(:status, :connected)
    |> Map.put(:warning, nil)
    |> Map.put(:error, nil)
  end

  def apply_stats_connection_state(call, _stats), do: call

  @doc "Takes in the browser's recovery report: the call's status and the warning or error it shows."
  @spec apply_recovery_state(map(), map()) :: map()
  def apply_recovery_state(call, payload) do
    recovery = GroupCallShape.normalize_recovery(payload)
    message = recovery.message || recovery_message(recovery.state)

    call = Map.put(call, :recovery, %{recovery | message: message})

    case recovery.state do
      :connected ->
        call
        |> Map.put(:status, :connected)
        |> Map.put(:warning, nil)
        |> Map.put(:error, nil)

      :connecting ->
        call
        |> Map.put(:status, :connecting)
        |> Map.put(:warning, message)
        |> Map.put(:error, nil)

      :reconnecting ->
        call
        |> Map.put(:status, :reconnecting)
        |> Map.put(:warning, message)
        |> Map.put(:error, nil)

      :rejoining ->
        call
        |> Map.put(:status, :reconnecting)
        |> Map.put(:warning, message)
        |> Map.put(:error, nil)

      :negotiating ->
        call
        |> Map.put(:status, :negotiating)
        |> Map.put(:warning, message)
        |> Map.put(:error, nil)

      :failed ->
        call
        |> Map.put(:status, :error)
        |> Map.put(:error, message)
        |> Map.put(:warning, nil)

      _state ->
        call
    end
  end

  @doc "The sentence for a recovery state, or nil."
  @spec recovery_message(atom()) :: String.t() | nil
  def recovery_message(:connecting),
    do: dgettext("group_call", "Group call media is connecting.")

  def recovery_message(:reconnecting),
    do: dgettext("group_call", "Group call media connection interrupted. Trying to recover.")

  def recovery_message(:rejoining),
    do: dgettext("group_call", "Rejoining the media session.")

  def recovery_message(:negotiating),
    do: dgettext("group_call", "Requesting a fresh media offer.")

  def recovery_message(:failed),
    do: dgettext("group_call", "Media recovery failed. Retry the media connection.")

  def recovery_message(_state), do: nil

  @doc "Reports a recovery transition to `RetroHexChat.Calls.Events`."
  @spec emit_group_call_recovery_transition(map()) :: :ok
  def emit_group_call_recovery_transition(recovery) do
    CallEvents.emit_recovery_transition(:group_call, recovery.state, recovery.reason, %{
      attempt: recovery.attempt,
      max_attempts: recovery.max_attempts,
      next_retry_ms: recovery.next_retry_ms,
      manual_retry: recovery.manual_retry,
      trigger: recovery.trigger
    })
  end
end
