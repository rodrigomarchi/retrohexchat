defmodule RetroHexChat.Commands.Policy do
  @moduledoc """
  Pre-dispatch permission and rate limit checks for commands.
  """

  alias RetroHexChat.Commands.Handler

  @spec pre_dispatch_check(String.t(), Handler.context()) :: :ok | {:error, String.t()}
  def pre_dispatch_check(_command_name, _context) do
    # Rate limit check will be wired in when RateLimit.Limiter is integrated
    # Permission checks will be added per-command as needed
    :ok
  end

  @spec require_channel(Handler.context()) :: :ok | {:error, String.t()}
  def require_channel(%{active_channel: nil}) do
    {:error, "You must be in a channel to use this command"}
  end

  def require_channel(%{active_channel: _}), do: :ok

  @spec require_identified(Handler.context()) :: :ok | {:error, String.t()}
  def require_identified(%{identified: true}), do: :ok

  def require_identified(_),
    do: {:error, "You must be identified with NickServ to use this command"}

  @spec require_operator(Handler.context(), String.t()) :: :ok | {:error, String.t()}
  def require_operator(%{operator_in: ops}, channel) do
    if channel in ops do
      :ok
    else
      {:error, "You must be a channel operator to use this command"}
    end
  end

  @spec require_admin(Handler.context()) :: :ok | {:error, String.t()}
  def require_admin(%{is_admin: true}), do: :ok
  def require_admin(_), do: {:error, "You must be a server administrator to use this command"}

  @spec require_owner(Handler.context(), String.t()) :: :ok | {:error, String.t()}
  def require_owner(context, channel) do
    owner_in = Map.get(context, :owner_in, [])

    if channel in owner_in do
      :ok
    else
      {:error, "You must be the channel owner to use this command"}
    end
  end
end
