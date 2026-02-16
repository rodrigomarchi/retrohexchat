# DataChannel Protocol Contract: P2P File Transfer

**Feature**: 037-p2p-file-transfer
**Date**: 2026-02-16

## Channel Configuration

- **Name**: `"filetransfer"`
- **Created by**: Initiator (connection creator) during WebRTC offer phase
- **Options**: `{ ordered: true }` (SCTP reliable ordered)
- **binaryType**: `"arraybuffer"`

## Message Format

All messages share a 1-byte type header at offset 0.

### Control Messages (Type 0x01-0x03, 0x05-0x09)

```
[1 byte: type] [N bytes: UTF-8 JSON payload]
```

### Data Message (Type 0x04 — Chunk)

```
[1 byte: 0x04] [4 bytes: Uint32BE chunk index] [≤65536 bytes: payload]
```

## Message Types

### 0x01 — file-offer

**Direction**: Sender → Receiver
**When**: After WebRTC DataChannel opens, sender has a file selected
**Payload**:
```json
{
  "transferId": "550e8400-e29b-41d4-a716-446655440000",
  "fileName": "relatorio-2026.pdf",
  "fileSize": 2516582,
  "mimeType": "application/pdf",
  "totalChunks": 39,
  "sha256": "a1b2c3d4e5f6...64 hex chars"
}
```

### 0x02 — file-accept

**Direction**: Receiver → Sender
**When**: Receiver clicks "Aceitar"
**Payload**:
```json
{
  "transferId": "550e8400-e29b-41d4-a716-446655440000"
}
```

### 0x03 — file-reject

**Direction**: Receiver → Sender
**When**: Receiver clicks "Rejeitar"
**Payload**:
```json
{
  "transferId": "550e8400-e29b-41d4-a716-446655440000"
}
```

### 0x04 — chunk

**Direction**: Sender → Receiver
**When**: Transfer is active, backpressure allows sending
**Binary format**:
```
Byte 0:     0x04
Bytes 1-4:  chunk index (Uint32 big-endian)
Bytes 5+:   file data (≤65536 bytes, last chunk may be smaller)
```

### 0x05 — cancel

**Direction**: Either → Other
**When**: User clicks "Cancelar" during offer or transfer
**Payload**:
```json
{
  "transferId": "550e8400-e29b-41d4-a716-446655440000",
  "cancelledBy": "mario"
}
```

### 0x06 — have-chunks

**Direction**: Receiver → Sender
**When**: After reconnection, receiver reports already-received chunks
**Binary format**:
```
Byte 0:     0x06
Bytes 1-4:  transferId length (Uint32BE)
Bytes 5-N:  transferId (UTF-8)
Bytes N+1+: Uint32BE array of received chunk indices
```

### 0x07 — transfer-done

**Direction**: Sender → Receiver
**When**: All chunks sent (or all missing chunks sent during resume)
**Payload**:
```json
{
  "transferId": "550e8400-e29b-41d4-a716-446655440000"
}
```

### 0x08 — hash-result

**Direction**: Receiver → Sender
**When**: After receiver computes SHA-256 and compares
**Payload**:
```json
{
  "transferId": "550e8400-e29b-41d4-a716-446655440000",
  "match": true
}
```

### 0x09 — retry

**Direction**: Sender → Receiver
**When**: Sender initiates full retry after hash mismatch
**Payload**:
```json
{
  "transferId": "550e8400-e29b-41d4-a716-446655440000"
}
```

## Sequence Diagrams

### Happy Path: File Transfer

```
Sender                          DataChannel                         Receiver
  |                                  |                                  |
  |-- file-offer (0x01) ----------->|--------------------------------->|
  |                                  |                                  |
  |<---------------------------------|<-- file-accept (0x02) ----------|
  |                                  |                                  |
  |-- chunk 0 (0x04) -------------->|--------------------------------->|
  |-- chunk 1 (0x04) -------------->|--------------------------------->|
  |-- ...                            |                                  |
  |-- chunk N (0x04) -------------->|--------------------------------->|
  |                                  |                                  |
  |-- transfer-done (0x07) -------->|--------------------------------->|
  |                                  |                                  |
  |                                  |    [Receiver computes SHA-256]   |
  |                                  |                                  |
  |<---------------------------------|<-- hash-result (0x08, match) ---|
  |                                  |                                  |
  [Both show success]               [Receiver triggers download]
```

### Resume After Disconnect

```
Sender                          DataChannel                         Receiver
  |                                  |                                  |
  |            [connection drops — WebRTC retry reconnects]             |
  |                                  |                                  |
  |<---------------------------------|<-- have-chunks (0x06) ----------|
  |                                  |    [indices: 0,1,2,...,N]       |
  |                                  |                                  |
  |-- chunk N+1 (0x04) ------------>|--------------------------------->|
  |-- chunk N+2 (0x04) ------------>|--------------------------------->|
  |-- ...missing chunks              |                                  |
  |                                  |                                  |
  |-- transfer-done (0x07) -------->|--------------------------------->|
  |                                  |                                  |
  |<---------------------------------|<-- hash-result (0x08) ----------|
```

### Cancellation

```
Canceller                       DataChannel                         Other Peer
  |                                  |                                  |
  |-- cancel (0x05) --------------->|--------------------------------->|
  |                                  |                                  |
  [Clean up partial data]           [Clean up partial data]
  [Show cancellation message]       [Show cancellation message]
```

## Backpressure Protocol

```
Sender loop:
  1. Read next chunk from File
  2. Check channel.bufferedAmount
     - If >= HIGH_WATER_MARK (1MB): pause, wait for bufferedamountlow event
     - If < HIGH_WATER_MARK: continue
  3. Send chunk via channel.send(buffer)
  4. Update progress
  5. Repeat from 1

channel.bufferedAmountLowThreshold = LOW_WATER_MARK (256KB)
channel.onbufferedamountlow = () => resume sending
```

## Constants

| Constant               | Value     | Description                        |
|----------------------- |---------- |----------------------------------- |
| CHUNK_SIZE             | 65536     | 64 KB per chunk                    |
| HIGH_WATER_MARK        | 1048576   | 1 MB — pause sending threshold     |
| LOW_WATER_MARK         | 262144    | 256 KB — resume sending threshold  |
| PROGRESS_THROTTLE_MS   | 250       | UI update interval                 |
| SPEED_WINDOW_MS        | 3000      | Rolling average window for speed   |
