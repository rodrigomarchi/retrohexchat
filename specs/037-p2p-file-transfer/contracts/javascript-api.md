# JavaScript API Contract: P2P File Transfer

**Feature**: 037-p2p-file-transfer
**Date**: 2026-02-16

## Module: `file_transfer.js` (Pure Logic Library)

**Location**: `apps/retro_hex_chat_web/assets/js/lib/file_transfer.js`
**Rule**: MUST NOT contain any DOM manipulation. Pure functions and state management only.

### Constants (exported)

```javascript
export const CHUNK_SIZE = 65536;           // 64 KB
export const HIGH_WATER_MARK = 1048576;    // 1 MB
export const LOW_WATER_MARK = 262144;      // 256 KB
export const PROGRESS_THROTTLE_MS = 250;
export const SPEED_WINDOW_MS = 3000;

export const MSG = {
  FILE_OFFER: 0x01,
  FILE_ACCEPT: 0x02,
  FILE_REJECT: 0x03,
  CHUNK: 0x04,
  CANCEL: 0x05,
  HAVE_CHUNKS: 0x06,
  TRANSFER_DONE: 0x07,
  HASH_RESULT: 0x08,
  RETRY: 0x09,
};

export const STATE = {
  IDLE: "idle",
  OFFERING: "offering",
  TRANSFERRING: "transferring",
  VERIFYING: "verifying",
  COMPLETED: "completed",
  FAILED: "failed",
  REJECTED: "rejected",
  CANCELLED: "cancelled",
  PAUSED: "paused",
};
```

### File Validation

```javascript
/**
 * Validate a file against size and extension restrictions.
 * @param {File} file - The File object to validate
 * @param {object} config - { maxSizeBytes: number, blockedExtensions: string[] }
 * @returns {{ valid: boolean, error?: string }}
 */
export function validateFile(file, config)
```

### Hashing

```javascript
/**
 * Compute SHA-256 hash of an ArrayBuffer.
 * @param {ArrayBuffer} buffer - The data to hash
 * @returns {Promise<string>} Hex-encoded SHA-256 hash
 */
export async function computeHash(buffer)
```

### Message Encoding/Decoding

```javascript
/**
 * Encode a control message (non-chunk) for DataChannel.
 * @param {number} type - Message type code (MSG.*)
 * @param {object} payload - JSON-serializable payload
 * @returns {ArrayBuffer}
 */
export function encodeControlMessage(type, payload)

/**
 * Encode a data chunk for DataChannel.
 * @param {number} chunkIndex - 0-based chunk index
 * @param {ArrayBuffer} data - Chunk payload
 * @returns {ArrayBuffer}
 */
export function encodeChunk(chunkIndex, data)

/**
 * Decode a DataChannel message.
 * @param {ArrayBuffer} buffer - Raw message from DataChannel
 * @returns {{ type: number, payload: object|ArrayBuffer, chunkIndex?: number }}
 */
export function decodeMessage(buffer)

/**
 * Encode have-chunks message with binary chunk indices.
 * @param {string} transferId
 * @param {Set<number>} receivedIndices
 * @returns {ArrayBuffer}
 */
export function encodeHaveChunks(transferId, receivedIndices)

/**
 * Decode have-chunks message.
 * @param {ArrayBuffer} buffer - Raw message (without type byte)
 * @returns {{ transferId: string, indices: Set<number> }}
 */
export function decodeHaveChunks(buffer)
```

### Transfer State Machine

```javascript
/**
 * Create a new transfer session (sender side).
 * @param {File} file - The file to send
 * @param {string} sha256 - Pre-computed hash
 * @returns {TransferSession}
 */
export function createSenderSession(file, sha256)

/**
 * Create a new transfer session (receiver side).
 * @param {object} offer - Decoded file-offer payload
 * @returns {TransferSession}
 */
export function createReceiverSession(offer)

/**
 * Get the next chunk to send, respecting already-sent and have-chunks.
 * @param {TransferSession} session - The sender session
 * @returns {Promise<{ index: number, data: ArrayBuffer } | null>} null when done
 */
export async function getNextChunk(session)

/**
 * Record a received chunk.
 * @param {TransferSession} session - The receiver session
 * @param {number} chunkIndex
 * @param {ArrayBuffer} data
 */
export function receiveChunk(session, chunkIndex, data)

/**
 * Assemble received chunks into a Blob for download.
 * @param {TransferSession} session - The receiver session
 * @returns {Blob}
 */
export function assembleFile(session)

/**
 * Clean up a transfer session (release memory).
 * @param {TransferSession} session
 */
export function cleanupSession(session)

/**
 * Mark chunks as already received (for resume).
 * @param {TransferSession} session - The sender session
 * @param {Set<number>} receivedIndices - Chunk indices the receiver has
 */
export function markChunksReceived(session, receivedIndices)
```

### Progress Calculation

```javascript
/**
 * Calculate transfer progress metrics.
 * @param {TransferSession} session
 * @returns {{ percent: number, speedBps: number, etaSeconds: number }}
 */
export function calculateProgress(session)

/**
 * Record a speed sample for rolling average.
 * @param {TransferSession} session
 * @param {number} bytesTransferred - Total bytes so far
 * @param {number} timestamp - Date.now()
 */
export function recordSpeedSample(session, bytesTransferred, timestamp)

/**
 * Format bytes for display (e.g., "2.4 MB").
 * @param {number} bytes
 * @returns {string}
 */
export function formatFileSize(bytes)

/**
 * Format speed for display (e.g., "350 KB/s").
 * @param {number} bytesPerSecond
 * @returns {string}
 */
export function formatSpeed(bytesPerSecond)

/**
 * Format ETA for display (e.g., "2m 15s").
 * @param {number} seconds
 * @returns {string}
 */
export function formatEta(seconds)
```

### Queue Management

```javascript
/**
 * Check if a transfer is currently active.
 * @param {TransferSession|null} session
 * @returns {boolean}
 */
export function isTransferActive(session)

/**
 * Create a queued transfer entry.
 * @param {File} file
 * @returns {{ file: File, queuedAt: number }}
 */
export function createQueueEntry(file)
```

---

## Module: `file_transfer_hook.js` (LiveView Hook — Wiring Only)

**Location**: `apps/retro_hex_chat_web/assets/js/hooks/file_transfer_hook.js`
**Rule**: MUST NOT contain transfer protocol logic. Wires DOM events to lib functions and LiveView pushEvent calls.

### Lifecycle

```javascript
export default {
  mounted() {
    // 1. Set up file input change listener
    // 2. Set up drag-and-drop listeners on lobby area
    // 3. Listen for DataChannel messages (from WebRTCHook coordination)
    // 4. Register handleEvent listeners for server-pushed events
  },

  destroyed() {
    // 1. Clean up active transfer session
    // 2. Remove event listeners
    // 3. Release object URLs
  }
}
```

### Server → Client Events (handleEvent)

| Event                    | Payload                           | Action                                    |
|------------------------- |---------------------------------- |------------------------------------------ |
| `ft_channel_ready`       | `{ channel: RTCDataChannel }`     | Store channel reference, enable file UI   |
| `ft_config`              | `{ maxSizeMB, blockedExts }`     | Store validation config                   |

### Client → Server Events (pushEvent)

| Event                    | Payload                           | When                                      |
|------------------------- |---------------------------------- |------------------------------------------ |
| `ft_offer_sent`          | `{ fileName, fileSize }`         | After sending file-offer via DataChannel  |
| `ft_offer_received`      | `{ fileName, fileSize, from }`   | After receiving file-offer from peer      |
| `ft_accepted`            | `{}`                             | Receiver accepted the offer               |
| `ft_rejected`            | `{}`                             | Receiver rejected the offer               |
| `ft_progress`            | `{ percent, speed, eta }`        | Periodic progress update                  |
| `ft_completed`           | `{ fileName }`                   | Transfer completed successfully           |
| `ft_failed`              | `{ reason }`                     | Transfer failed                           |
| `ft_cancelled`           | `{ cancelledBy }`                | Transfer cancelled                        |

### DOM Interactions

- **File input**: Hidden `<input type="file">`, triggered by button click
- **Drag-and-drop**: `dragenter`, `dragover`, `dragleave`, `drop` on lobby container
- **Progress bar**: Updates `style.width` on `.progress-indicator-bar`
- **Download trigger**: Creates hidden `<a>` with `URL.createObjectURL()`, clicks it, revokes URL
