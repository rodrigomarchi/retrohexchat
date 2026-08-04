defmodule RetroHexChat.Bots.Policy do
  @moduledoc """
  Authorization checks for bot management.
  Only admins and server operators can create/manage bots.

  Two entry points ask the same question from different distances. A command
  arrives with the asker's roles already resolved from their session, so
  `can_manage?/1` just reads them. A message in a channel arrives with nothing
  but a nickname, so `admin?/1` has to resolve the roles itself.
  """
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Accounts.ServerRoles
  alias RetroHexChat.Bots.Identity

  # Open on purpose: callers hand over a whole command context — nickname,
  # channels, modes — and this module reads two keys out of it. Declaring the
  # closed pair says "a map with exactly these", which no real caller is.
  @type context :: %{
          required(:is_admin) => boolean(),
          required(:is_server_operator) => boolean(),
          optional(any()) => any()
        }

  @spec can_manage?(context()) :: boolean()
  def can_manage?(%{is_admin: true}), do: true
  def can_manage?(%{is_server_operator: true}), do: true
  def can_manage?(_), do: false

  @doc """
  Whether a nickname carries server privilege, resolved live.

  Call this only when someone is actually asking to change something. Resolving
  identification means a call into NickServ, which is the busiest process on the
  server — put it in the path of every channel message and every bot in the room
  queues behind whatever NickServ is doing.

  Fails closed: an unreachable or slow NickServ denies rather than crashes the
  bot, because the alternative is a supervisor restart triggered by anyone who
  types the command at the wrong moment.
  """
  @spec admin?(String.t() | nil) :: boolean()
  def admin?(nil), do: false

  def admin?(nickname) when is_binary(nickname) do
    identified = Identity.impl().identified?(nickname)

    ServerRoles.admin?(nickname, identified) or
      ServerRoles.server_operator?(nickname, identified)
  catch
    :exit, _reason -> false
  end

  def admin?(_), do: false

  @spec can_create?(context()) :: boolean()
  def can_create?(context), do: can_manage?(context)

  @spec authorize(context()) :: :ok | {:error, String.t()}
  def authorize(context) do
    if can_manage?(context),
      do: :ok,
      else: {:error, dgettext("bots", "Only admins and server operators can manage bots")}
  end
end
