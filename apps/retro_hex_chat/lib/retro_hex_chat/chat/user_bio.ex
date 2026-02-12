defmodule RetroHexChat.Chat.UserBio do
  @moduledoc """
  Domain module for managing user bio text.
  Provides persistence functions (save/2, load/1, delete/1) for registered users.
  """

  alias RetroHexChat.Chat.Schemas.UserBio, as: UserBioSchema
  alias RetroHexChat.Repo

  @spec save(String.t(), String.t()) :: :ok | {:error, term()}
  def save(owner, bio_text) do
    attrs = %{owner_nickname: owner, bio_text: bio_text}

    case Repo.get(UserBioSchema, owner) do
      nil ->
        %UserBioSchema{}
        |> UserBioSchema.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> UserBioSchema.changeset(attrs)
        |> Repo.update()
    end
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec load(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def load(owner) do
    case Repo.get(UserBioSchema, owner) do
      nil -> {:error, :not_found}
      db_entry -> {:ok, db_entry.bio_text}
    end
  end

  @spec delete(String.t()) :: :ok
  def delete(owner) do
    case Repo.get(UserBioSchema, owner) do
      nil -> :ok
      existing -> Repo.delete(existing)
    end

    :ok
  end
end
