defmodule RetroHexChat.Accounts.ServerRoles do
  @moduledoc """
  Server-level role checks against application configuration.
  Users must be identified via NickServ to activate privileges.
  """

  @spec admin?(String.t(), boolean()) :: boolean()
  def admin?(nickname, identified) do
    identified and nickname in admin_list()
  end

  @spec server_operator?(String.t(), boolean()) :: boolean()
  def server_operator?(nickname, identified) do
    identified and nickname in server_operator_list()
  end

  @spec admin_list() :: [String.t()]
  def admin_list do
    Application.get_env(:retro_hex_chat, :admins, [])
  end

  @spec server_operator_list() :: [String.t()]
  def server_operator_list do
    Application.get_env(:retro_hex_chat, :server_operators, [])
  end
end
