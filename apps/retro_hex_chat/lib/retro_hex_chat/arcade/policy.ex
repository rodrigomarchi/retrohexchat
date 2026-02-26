defmodule RetroHexChat.Arcade.Policy do
  @moduledoc """
  Authorization rules for solo arcade session operations.
  """

  import Ecto.Query

  alias RetroHexChat.Arcade.Schema.SoloSession
  alias RetroHexChat.Repo

  @spec can_create?(integer()) :: :ok | {:error, String.t()}
  def can_create?(creator_id) do
    check_registered(creator_id)
  end

  @spec can_join?(integer(), SoloSession.t()) :: :ok | {:error, String.t()}
  def can_join?(user_id, session) do
    with :ok <- check_creator(user_id, session),
         :ok <- check_not_terminal(session) do
      :ok
    end
  end

  @spec can_close?(integer(), SoloSession.t()) :: :ok | {:error, String.t()}
  def can_close?(user_id, session) do
    with :ok <- check_creator(user_id, session),
         :ok <- check_not_terminal(session) do
      :ok
    end
  end

  defp check_registered(user_id) do
    exists =
      from(r in "registered_nicks", where: r.id == ^user_id, select: true)
      |> Repo.exists?()

    if exists do
      :ok
    else
      {:error, "You must be registered to play arcade games"}
    end
  end

  defp check_creator(user_id, session) do
    if user_id == session.creator_id do
      :ok
    else
      {:error, "You are not the owner of this arcade session"}
    end
  end

  defp check_not_terminal(session) do
    if SoloSession.terminal?(session.status) do
      {:error, "Arcade session is no longer active"}
    else
      :ok
    end
  end
end
