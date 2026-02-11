# Contract: Policy Extension for Format Validation

**Module**: `RetroHexChat.Chat.Policy`
**Context**: `RetroHexChat.Chat`
**Purpose**: Extend content validation to handle format-code-only messages.

## Modified Function

### `validate_content(content) :: :ok | {:error, String.t()}`

**Current behavior**:
- Rejects empty strings
- Rejects content exceeding 1000 characters

**New behavior** (additional check):
- After existing checks pass, strip all mIRC format codes using `Formatter.strip/1`
- If stripped content is empty or whitespace-only, return `{:error, "Message cannot be empty"}`

**Examples**:
```elixir
Policy.validate_content("\x02\x03")
# => {:error, "Message cannot be empty"}

Policy.validate_content("\x02Hello\x02")
# => :ok

Policy.validate_content("\x02   \x02")
# => {:error, "Message cannot be empty"}

Policy.validate_content("Normal text")
# => :ok
```

**Note**: The 1000-character max length check applies to the full string including control codes. This is intentional — control codes count toward the limit.
