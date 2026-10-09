defmodule RetroHexChat.Commands.Timestamp do
  @moduledoc """
  How a command's text reply writes a moment: UTC, to the minute, labelled.

  A reply is built in the domain, which never knows the reader's time zone, so
  it says which zone it is in rather than printing a bare ISO stamp with
  microseconds.
  """
  use Gettext, backend: RetroHexChat.Gettext

  @spec format(DateTime.t() | NaiveDateTime.t() | nil) :: String.t()
  def format(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M UTC")

  def format(%NaiveDateTime{} = datetime),
    do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M UTC")

  def format(_missing), do: dgettext("commands", "unknown")
end
