defmodule RetroHexChat.Notifications.Schema.PushSubscription do
  @moduledoc """
  One browser that has agreed to be woken up for one registered nickname.

  The endpoint is the browser's own address at its push service and is the
  identity of the row: the same browser subscribing twice is one subscription,
  not two, and treating it as two is how one person gets every notification in
  duplicate.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "push_subscriptions" do
    field :owner_nickname, :string
    field :endpoint, :string
    field :p256dh, :string
    field :auth, :string
    field :user_agent, :string
    field :last_success_at, :utc_datetime_usec
    field :failure_count, :integer, default: 0

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [
      :owner_nickname,
      :endpoint,
      :p256dh,
      :auth,
      :user_agent,
      :last_success_at,
      :failure_count
    ])
    |> validate_required([:owner_nickname, :endpoint, :p256dh, :auth])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_length(:endpoint, max: 2000)
    |> validate_length(:p256dh, max: 255)
    |> validate_length(:auth, max: 255)
    |> validate_length(:user_agent, max: 255)
    |> unique_constraint(:endpoint)
    |> foreign_key_constraint(:owner_nickname,
      name: :push_subscriptions_owner_nickname_fkey
    )
  end
end
