defmodule RetroHexChat.Bots.Policy do
  @moduledoc """
  Authorization checks for bot management.
  Only admins and server operators can create/manage bots.
  """
  use Gettext, backend: RetroHexChat.Gettext

  @type context :: %{
          is_admin: boolean(),
          is_server_operator: boolean()
        }

  @spec can_manage?(context()) :: boolean()
  def can_manage?(%{is_admin: true}), do: true
  def can_manage?(%{is_server_operator: true}), do: true
  def can_manage?(_), do: false

  @spec can_create?(context()) :: boolean()
  def can_create?(context), do: can_manage?(context)

  @spec authorize(context()) :: :ok | {:error, String.t()}
  def authorize(context) do
    if can_manage?(context),
      do: :ok,
      else: {:error, dgettext("bots", "Only admins and server operators can manage bots")}
  end
end
