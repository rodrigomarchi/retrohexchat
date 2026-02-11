# Contract: Service Queries Extensions

**Feature**: 007-channel-central
**Module**: `RetroHexChat.Services.Queries`

## New Functions

### Ban Exception Queries

```elixir
@spec add_ban_exception(String.t(), String.t(), String.t()) ::
        {:ok, BanException.t()} | {:error, Ecto.Changeset.t()}
def add_ban_exception(channel_name, nickname, added_by)
```

Insert a ban exception record. Returns `{:error, changeset}` if duplicate (unique constraint).

```elixir
@spec remove_ban_exception(String.t(), String.t()) :: :ok | {:error, :not_found}
def remove_ban_exception(channel_name, nickname)
```

Delete a ban exception record. Returns `{:error, :not_found}` if not in DB.

```elixir
@spec list_ban_exceptions(String.t()) :: [BanException.t()]
def list_ban_exceptions(channel_name)
```

Retrieve all ban exceptions for a channel, ordered by inserted_at.

### Invite Exception Queries

```elixir
@spec add_invite_exception(String.t(), String.t(), String.t()) ::
        {:ok, InviteException.t()} | {:error, Ecto.Changeset.t()}
def add_invite_exception(channel_name, nickname, added_by)
```

Insert an invite exception record.

```elixir
@spec remove_invite_exception(String.t(), String.t()) :: :ok | {:error, :not_found}
def remove_invite_exception(channel_name, nickname)
```

Delete an invite exception record.

```elixir
@spec list_invite_exceptions(String.t()) :: [InviteException.t()]
def list_invite_exceptions(channel_name)
```

Retrieve all invite exceptions for a channel, ordered by inserted_at.

## Extended Functions

### load_persisted_state/1 (extended)

Now also loads ban exceptions and invite exceptions:

```elixir
%{
  # ... existing fields ...
  bans: [nickname, ...],
  ban_exceptions: [nickname, ...],      # NEW
  invite_exceptions: [nickname, ...]     # NEW
}
```

## Ecto Schemas

### BanException

```elixir
schema "ban_exceptions" do
  field :channel_name, :string
  field :nickname, :string
  field :added_by, :string
  timestamps(type: :utc_datetime_usec, updated_at: false)
end
```

### InviteException

```elixir
schema "invite_exceptions" do
  field :channel_name, :string
  field :nickname, :string
  field :added_by, :string
  timestamps(type: :utc_datetime_usec, updated_at: false)
end
```
