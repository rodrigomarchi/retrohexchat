/**
 * P2P file transfer protocol — pure logic, no DOM or LiveView dependencies.
 * @module file_transfer
 */

// --- Constants ---

export const CHUNK_SIZE = 65536; // 64 KB
export const HIGH_WATER_MARK = 1048576; // 1 MB
export const LOW_WATER_MARK = 262144; // 256 KB
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

// --- File Validation ---

/**
 * Validate a file against size and extension restrictions.
 * @param {File} file
 * @param {{ maxSizeBytes: number, blockedExtensions: string[] }} config
 * @returns {{ valid: boolean, error?: string }}
 */
export function validateFile(file, config) {
  if (file.size > config.maxSizeBytes) {
    const maxMB = Math.round(config.maxSizeBytes / (1024 * 1024));
    return {
      valid: false,
      error: `Arquivo excede o limite de ${maxMB} MB (${formatFileSize(file.size)})`,
    };
  }

  const ext = extractExtension(file.name);
  if (ext) {
    const blocked = config.blockedExtensions.find((b) => b.toLowerCase() === ext.toLowerCase());
    if (blocked) {
      return {
        valid: false,
        error: `Tipo de arquivo bloqueado: ${blocked.toLowerCase()}`,
      };
    }
  }

  return { valid: true };
}

function extractExtension(fileName) {
  const dotIndex = fileName.lastIndexOf(".");
  if (dotIndex <= 0) return null;
  return fileName.slice(dotIndex).toLowerCase();
}

// --- Message Encoding/Decoding ---

/**
 * Encode a control message (non-chunk) for DataChannel.
 * @param {number} type
 * @param {object} payload
 * @returns {ArrayBuffer}
 */
export function encodeControlMessage(type, payload) {
  const json = JSON.stringify(payload);
  const encoder = new TextEncoder();
  const jsonBytes = encoder.encode(json);
  const buffer = new ArrayBuffer(1 + jsonBytes.length);
  const view = new Uint8Array(buffer);
  view[0] = type;
  view.set(jsonBytes, 1);
  return buffer;
}

/**
 * Encode a data chunk for DataChannel.
 * @param {number} chunkIndex
 * @param {ArrayBuffer} data
 * @returns {ArrayBuffer}
 */
export function encodeChunk(chunkIndex, data) {
  const buffer = new ArrayBuffer(1 + 4 + data.byteLength);
  const view = new DataView(buffer);
  view.setUint8(0, MSG.CHUNK);
  view.setUint32(1, chunkIndex, false); // big-endian
  new Uint8Array(buffer, 5).set(new Uint8Array(data));
  return buffer;
}

/**
 * Decode a DataChannel message.
 * @param {ArrayBuffer} buffer
 * @returns {{ type: number, payload?: object, chunkIndex?: number }}
 */
export function decodeMessage(buffer) {
  const view = new DataView(buffer);
  const type = view.getUint8(0);

  if (type === MSG.CHUNK) {
    const chunkIndex = view.getUint32(1, false);
    const payload = buffer.slice(5);
    return { type, chunkIndex, payload };
  }

  // Control message — JSON payload
  const decoder = new TextDecoder();
  const json = decoder.decode(new Uint8Array(buffer, 1));
  return { type, payload: JSON.parse(json) };
}

/**
 * Encode have-chunks message with binary chunk indices.
 * @param {string} transferId
 * @param {Set<number>} receivedIndices
 * @returns {ArrayBuffer}
 */
export function encodeHaveChunks(transferId, receivedIndices) {
  const encoder = new TextEncoder();
  const idBytes = encoder.encode(transferId);
  const indices = Array.from(receivedIndices);
  const buffer = new ArrayBuffer(4 + idBytes.length + indices.length * 4);
  const view = new DataView(buffer);

  view.setUint32(0, idBytes.length, false);
  new Uint8Array(buffer, 4, idBytes.length).set(idBytes);

  let offset = 4 + idBytes.length;
  for (const idx of indices) {
    view.setUint32(offset, idx, false);
    offset += 4;
  }

  return buffer;
}

/**
 * Decode have-chunks message.
 * @param {ArrayBuffer} buffer - Raw message (without type byte)
 * @returns {{ transferId: string, indices: Set<number> }}
 */
export function decodeHaveChunks(buffer) {
  const view = new DataView(buffer);
  const idLen = view.getUint32(0, false);
  const decoder = new TextDecoder();
  const transferId = decoder.decode(new Uint8Array(buffer, 4, idLen));

  const indices = new Set();
  let offset = 4 + idLen;
  while (offset + 4 <= buffer.byteLength) {
    indices.add(view.getUint32(offset, false));
    offset += 4;
  }

  return { transferId, indices };
}

// --- Hashing ---

/**
 * Compute SHA-256 hash of an ArrayBuffer.
 * @param {ArrayBuffer} buffer
 * @returns {Promise<string>}
 */
export async function computeHash(buffer) {
  const hashBuffer = await crypto.subtle.digest("SHA-256", new Uint8Array(buffer));
  const hashArray = new Uint8Array(hashBuffer);
  return Array.from(hashArray)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// --- Formatting ---

/**
 * Format bytes for display.
 * @param {number} bytes
 * @returns {string}
 */
export function formatFileSize(bytes) {
  if (bytes === 0) return "0 B";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`;
}

/**
 * Format speed for display.
 * @param {number} bytesPerSecond
 * @returns {string}
 */
export function formatSpeed(bytesPerSecond) {
  if (bytesPerSecond === 0) return "0 B/s";
  if (bytesPerSecond < 1024) return `${Math.round(bytesPerSecond)} B/s`;
  if (bytesPerSecond < 1024 * 1024) return `${(bytesPerSecond / 1024).toFixed(1)} KB/s`;
  return `${(bytesPerSecond / (1024 * 1024)).toFixed(1)} MB/s`;
}

/**
 * Format ETA for display.
 * @param {number} seconds
 * @returns {string}
 */
export function formatEta(seconds) {
  if (!isFinite(seconds)) return "--";
  if (seconds === 0) return "0s";

  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);

  if (h > 0) return `${h}h ${m}m ${s}s`;
  if (m > 0) return `${m}m ${s}s`;
  return `${s}s`;
}

// --- Transfer Session Management ---

let idCounter = 0;

function generateTransferId() {
  idCounter++;
  const ts = Date.now().toString(36);
  const rnd = Math.random().toString(36).slice(2, 8);
  return `${ts}-${rnd}-${idCounter}`;
}

/**
 * Create a new transfer session (sender side).
 * @param {File} file
 * @param {string} sha256
 * @returns {object}
 */
export function createSenderSession(file, sha256) {
  const totalChunks = Math.ceil(file.size / CHUNK_SIZE);
  return {
    transferId: generateTransferId(),
    role: "sender",
    state: STATE.OFFERING,
    file,
    chunks: null,
    receivedSet: null,
    sentSet: new Set(),
    nextChunkIndex: 0,
    totalChunks,
    bytesSent: 0,
    bytesReceived: 0,
    fileSize: file.size,
    fileName: file.name,
    mimeType: file.type,
    expectedHash: sha256,
    startTime: null,
    speedSamples: [],
  };
}

/**
 * Create a new transfer session (receiver side).
 * @param {object} offer
 * @returns {object}
 */
export function createReceiverSession(offer) {
  return {
    transferId: offer.transferId,
    role: "receiver",
    state: STATE.TRANSFERRING,
    file: null,
    chunks: new Array(offer.totalChunks).fill(null),
    receivedSet: new Set(),
    sentSet: null,
    nextChunkIndex: 0,
    totalChunks: offer.totalChunks,
    bytesSent: 0,
    bytesReceived: 0,
    fileSize: offer.fileSize,
    fileName: offer.fileName,
    mimeType: offer.mimeType,
    expectedHash: offer.sha256,
    startTime: Date.now(),
    speedSamples: [],
  };
}

/**
 * Get the next chunk to send.
 * @param {object} session
 * @returns {Promise<{index: number, data: ArrayBuffer}|null>}
 */
export async function getNextChunk(session) {
  while (session.nextChunkIndex < session.totalChunks) {
    const index = session.nextChunkIndex;
    session.nextChunkIndex++;

    if (session.sentSet.has(index)) continue;

    const start = index * CHUNK_SIZE;
    const end = Math.min(start + CHUNK_SIZE, session.fileSize);
    const blob = session.file.slice(start, end);
    const data = await blob.arrayBuffer();

    session.sentSet.add(index);
    session.bytesSent += data.byteLength;

    return { index, data };
  }

  return null;
}

/**
 * Record a received chunk.
 * @param {object} session
 * @param {number} chunkIndex
 * @param {ArrayBuffer} data
 */
export function receiveChunk(session, chunkIndex, data) {
  if (session.receivedSet.has(chunkIndex)) return;

  session.chunks[chunkIndex] = data;
  session.receivedSet.add(chunkIndex);
  session.bytesReceived += data.byteLength;
}

/**
 * Assemble received chunks into a Blob.
 * @param {object} session
 * @returns {Blob}
 */
export function assembleFile(session) {
  return new Blob(session.chunks, { type: session.mimeType });
}

/**
 * Clean up a transfer session.
 * @param {object} session
 */
export function cleanupSession(session) {
  session.chunks = null;
  session.file = null;
  session.receivedSet = null;
  session.sentSet = null;
  session.speedSamples = null;
  session.state = STATE.IDLE;
}

/**
 * Mark chunks as already received (for resume).
 * @param {object} session
 * @param {Set<number>} receivedIndices
 */
export function markChunksReceived(session, receivedIndices) {
  for (const idx of receivedIndices) {
    session.sentSet.add(idx);
  }
  // Recalculate bytesSent based on marked chunks
  session.bytesSent = receivedIndices.size * CHUNK_SIZE;
  // Cap to fileSize for the last chunk
  if (session.bytesSent > session.fileSize) {
    session.bytesSent = session.fileSize;
  }
}

// --- Progress ---

/**
 * Calculate transfer progress metrics.
 * @param {object} session
 * @returns {{ percent: number, speedBps: number, etaSeconds: number }}
 */
export function calculateProgress(session) {
  const transferred = session.role === "sender" ? session.bytesSent : session.bytesReceived;
  const percent = session.fileSize > 0 ? Math.round((transferred / session.fileSize) * 100) : 0;

  let speedBps = 0;
  if (session.speedSamples && session.speedSamples.length >= 2) {
    const first = session.speedSamples[0];
    const last = session.speedSamples[session.speedSamples.length - 1];
    const timeDiff = (last.timestamp - first.timestamp) / 1000;
    const bytesDiff = last.bytes - first.bytes;
    speedBps = timeDiff > 0 ? bytesDiff / timeDiff : 0;
  }

  const remaining = session.fileSize - transferred;
  const etaSeconds = speedBps > 0 ? remaining / speedBps : Infinity;

  return { percent, speedBps, etaSeconds };
}

/**
 * Record a speed sample for rolling average.
 * @param {object} session
 * @param {number} bytesTransferred
 * @param {number} timestamp
 */
export function recordSpeedSample(session, bytesTransferred, timestamp) {
  session.speedSamples.push({ bytes: bytesTransferred, timestamp });

  // Prune samples older than SPEED_WINDOW_MS
  const cutoff = timestamp - SPEED_WINDOW_MS;
  while (session.speedSamples.length > 0 && session.speedSamples[0].timestamp < cutoff) {
    session.speedSamples.shift();
  }
}

// --- Queue Management ---

/**
 * Check if a transfer is currently active.
 * @param {object|null} session
 * @returns {boolean}
 */
export function isTransferActive(session) {
  if (!session) return false;
  return [STATE.OFFERING, STATE.TRANSFERRING, STATE.VERIFYING, STATE.PAUSED].includes(
    session.state,
  );
}

/**
 * Create a queued transfer entry.
 * @param {File} file
 * @returns {{ file: File, queuedAt: number }}
 */
export function createQueueEntry(file) {
  return { file, queuedAt: Date.now() };
}
