# Data Model: Text Formatting & Colors

**Feature Branch**: `001-text-formatting-colors`
**Date**: 2026-02-11

## Overview

This feature introduces **no new database tables or migrations**. Format control codes are stored inline in the existing `content` field of `messages` and `private_messages` tables. All new data structures are runtime-only (in-memory).

## Modified Entities

### Session (Runtime — Accounts.Session struct)

**New field**:

| Field             | Type      | Default | Description                                       |
|-------------------|-----------|---------|---------------------------------------------------|
| strip_formatting  | boolean() | false   | When true, display all messages as plain text      |

**State transitions**: Toggled on/off by user action. Resets to `false` on reconnect (new session).

### Message Content (Existing — Chat.Message / Chat.PrivateMessage)

**No schema change**. The `content` field (`:string`) already accepts arbitrary Unicode, including the control characters used by mIRC formatting (0x02, 0x03, 0x0F, 0x16, 0x1D, 0x1E, 0x1F). PostgreSQL `text` type stores these without issue.

**Content format examples**:

```
Plain text: "Hello world"
Bold:       "\x02Hello\x02 world"
Color:      "\x034Red text\x03 normal"
Color+BG:   "\x034,1Red on black\x03"
Combined:   "\x02\x034Bold red\x03\x02 normal"
Reset:      "\x02Bold \x0Freset all"
```

## New Domain Types (Runtime)

### FormatterState (internal to Chat.Formatter)

Tracks active formatting while parsing a message. Not persisted.

| Field       | Type               | Default | Description                         |
|-------------|--------------------|---------|-------------------------------------|
| bold        | boolean()          | false   | Bold toggle active                  |
| italic      | boolean()          | false   | Italic toggle active                |
| underline   | boolean()          | false   | Underline toggle active             |
| strikethrough | boolean()        | false   | Strikethrough toggle active         |
| reverse     | boolean()          | false   | Reverse video toggle active         |
| fg_color    | integer() \| nil   | nil     | Foreground color (0–15) or nil      |
| bg_color    | integer() \| nil   | nil     | Background color (0–15) or nil      |

**State transitions**:
- Toggle codes (0x02, 0x1D, 0x1F, 0x1E, 0x16): flip the corresponding boolean
- Color code (0x03): set fg_color (and optionally bg_color) from parsed digits; bare 0x03 resets both to nil
- Reset (0x0F): all fields return to defaults

### Color Palette (constant)

16 standard mIRC colors. Immutable lookup table.

| Index | Name        | Hex       |
|-------|-------------|-----------|
| 0     | White       | #FFFFFF   |
| 1     | Black       | #000000   |
| 2     | Navy        | #00007F   |
| 3     | Green       | #009300   |
| 4     | Red         | #FF0000   |
| 5     | Brown       | #7F0000   |
| 6     | Purple      | #9C009C   |
| 7     | Orange      | #FC7F00   |
| 8     | Yellow      | #FFFF00   |
| 9     | Light Green | #00FC00   |
| 10    | Teal        | #009393   |
| 11    | Cyan        | #00FFFF   |
| 12    | Blue        | #0000FC   |
| 13    | Pink        | #FF00FF   |
| 14    | Grey        | #7F7F7F   |
| 15    | Light Grey  | #D2D2D2   |

## Relationships

```
Message.content ──contains──▶ Format Codes (inline control characters)
                                    │
                                    ▼
                           Chat.Formatter.parse/1
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
             to_safe_html/1    strip/1     visible_text/1
             (formatted HTML)  (plain text) (for validation)
```

## Validation Rules

1. **Content length**: Existing max 1000 characters applies to the full string including control codes.
2. **Visible text required**: After stripping all control codes, message must contain at least one non-whitespace character.
3. **Format code limit**: Soft limit of 128 format codes per message. Excess stripped at display time.
4. **Color code validity**: Numbers 0–15 are valid. Numbers > 15 are not consumed as color codes.
