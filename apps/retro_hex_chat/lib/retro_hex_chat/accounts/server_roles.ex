defmodule RetroHexChat.Accounts.ServerRoles do
  @moduledoc """
  Server-level role checks. Checks 3 sources in priority order:
  1. Root admins (ROOT_ADMINS env var, immutable)
  2. DB roles via RoleCache ETS
  3. Config fallback (legacy :admins / :server_operators)

  Users must be identified via NickServ to activate privileges.
  """

  alias RetroHexChat.Admin.RoleCache

  @spec admin?(String.t(), boolean()) :: boolean()
  def admin?(nickname, identified) do
    identified and
      (root_admin?(nickname) or RoleCache.admin?(nickname) or
         nickname in config_admin_list())
  end

  @spec server_operator?(String.t(), boolean()) :: boolean()
  def server_operator?(nickname, identified) do
    identified and
      (RoleCache.server_operator?(nickname) or nickname in config_server_operator_list())
  end

  @spec root_admin?(String.t()) :: boolean()
  def root_admin?(nickname) do
    nickname in root_admin_list()
  end

  @spec root_admin_list() :: [String.t()]
  def root_admin_list do
    Application.get_env(:retro_hex_chat, :root_admins, [])
  end

  @spec admin_list() :: [String.t()]
  def admin_list do
    (root_admin_list() ++ RoleCache.list_admin_nicks() ++ config_admin_list())
    |> Enum.uniq()
  end

  @spec server_operator_list() :: [String.t()]
  def server_operator_list do
    config_server_operator_list()
  end

  defp config_admin_list do
    Application.get_env(:retro_hex_chat, :admins, [])
  end

  defp config_server_operator_list do
    Application.get_env(:retro_hex_chat, :server_operators, [])
  end
end
