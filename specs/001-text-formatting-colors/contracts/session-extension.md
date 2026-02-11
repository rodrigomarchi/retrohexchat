# Contract: Session Extension for Strip Formatting

**Module**: `RetroHexChat.Accounts.Session`
**Context**: `RetroHexChat.Accounts`
**Purpose**: Add strip_formatting preference to user session.

## Schema Change

### New Field

```elixir
# Added to defstruct and @type t
strip_formatting: false  # boolean(), default false
```

## New/Modified Functions

### `toggle_strip_formatting(session) :: t()`

Toggles the `strip_formatting` field between `true` and `false`.

**Example**:
```elixir
session = %Session{strip_formatting: false}
Session.toggle_strip_formatting(session)
# => %Session{strip_formatting: true}
```
