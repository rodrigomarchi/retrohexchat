defmodule RetroHexChat.NamedTimers do
  @moduledoc """
  The deadlines a session process keeps, reached by name rather than by handle.

  A session server holds several at once — the one that expires a session
  nobody joined, the one that warns before an idle lobby closes, the one that
  gives a departing peer a moment to come back — and each fires as
  `{:timeout, name}`. The handles live under `state.timers`, which is what lets
  a session drop all of them at once when it ends without listing them.

  Scheduling a name that already holds a live timer cancels it first. Writing
  the new handle over the old one would leave the old timer running with
  nothing holding its reference, and the process would be woken twice for one
  deadline. Every caller already cancelled by hand before rescheduling, so the
  rule was real; it just lived in whoever remembered it rather than in the
  operation.

  A name is present only while its deadline is pending: cancelling drops it,
  and so does replacing it. `Process.cancel_timer/1` on a handle whose message
  is already in the mailbox does not unsend it, so a handler woken by a
  deadline still checks the state that deadline was about.
  """

  @typedoc "A process state holding its pending deadlines under `:timers`."
  @type state :: %{
          required(:timers) => %{optional(term()) => reference()},
          optional(any()) => any()
        }

  @doc """
  Wakes this process with `{:timeout, name}` in `delay` milliseconds.

  Replaces whatever `name` was already waiting for.
  """
  @spec schedule(state(), term(), non_neg_integer()) :: state()
  def schedule(state, name, delay) do
    state = cancel(state, name)
    ref = Process.send_after(self(), {:timeout, name}, delay)

    %{state | timers: Map.put(state.timers, name, ref)}
  end

  @doc "Drops the deadline kept under `name`, if there is one."
  @spec cancel(state(), term()) :: state()
  def cancel(state, name) do
    case Map.pop(state.timers, name) do
      {nil, _timers} ->
        state

      {ref, remaining} ->
        Process.cancel_timer(ref)
        %{state | timers: remaining}
    end
  end

  @doc "Drops every pending deadline, which is what ending a session does."
  @spec cancel_all(state()) :: state()
  def cancel_all(state) do
    Enum.each(state.timers, fn {_name, ref} -> Process.cancel_timer(ref) end)

    %{state | timers: %{}}
  end
end
