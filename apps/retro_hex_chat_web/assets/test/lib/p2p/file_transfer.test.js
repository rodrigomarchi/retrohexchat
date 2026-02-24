import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import {
  CHUNK_SIZE,
  HIGH_WATER_MARK,
  LOW_WATER_MARK,
  PROGRESS_THROTTLE_MS,
  SPEED_WINDOW_MS,
  MSG,
  STATE,
  validateFile,
  encodeControlMessage,
  encodeChunk,
  decodeMessage,
  computeHash,
  formatFileSize,
  formatSpeed,
  formatEta,
  createSenderSession,
  createReceiverSession,
  getNextChunk,
  receiveChunk,
  assembleFile,
  cleanupSession,
  calculateProgress,
  recordSpeedSample,
  encodeHaveChunks,
  decodeHaveChunks,
  markChunksReceived,
  isTransferActive,
  createQueueEntry,
} from "../../../js/lib/p2p/file_transfer.js";

// --- Phase 2: Foundation Tests (T005-T009) ---

describe("constants", () => {
  it("exports CHUNK_SIZE as 64KB", () => {
    expect(CHUNK_SIZE).toBe(65536);
  });

  it("exports HIGH_WATER_MARK as 1MB", () => {
    expect(HIGH_WATER_MARK).toBe(1048576);
  });

  it("exports LOW_WATER_MARK as 256KB", () => {
    expect(LOW_WATER_MARK).toBe(262144);
  });

  it("exports PROGRESS_THROTTLE_MS as 250", () => {
    expect(PROGRESS_THROTTLE_MS).toBe(250);
  });

  it("exports SPEED_WINDOW_MS as 3000", () => {
    expect(SPEED_WINDOW_MS).toBe(3000);
  });

  it("exports all MSG type codes", () => {
    expect(MSG.FILE_OFFER).toBe(0x01);
    expect(MSG.FILE_ACCEPT).toBe(0x02);
    expect(MSG.FILE_REJECT).toBe(0x03);
    expect(MSG.CHUNK).toBe(0x04);
    expect(MSG.CANCEL).toBe(0x05);
    expect(MSG.HAVE_CHUNKS).toBe(0x06);
    expect(MSG.TRANSFER_DONE).toBe(0x07);
    expect(MSG.HASH_RESULT).toBe(0x08);
    expect(MSG.RETRY).toBe(0x09);
  });

  it("exports all STATE values", () => {
    expect(STATE.IDLE).toBe("idle");
    expect(STATE.OFFERING).toBe("offering");
    expect(STATE.TRANSFERRING).toBe("transferring");
    expect(STATE.VERIFYING).toBe("verifying");
    expect(STATE.COMPLETED).toBe("completed");
    expect(STATE.FAILED).toBe("failed");
    expect(STATE.REJECTED).toBe("rejected");
    expect(STATE.CANCELLED).toBe("cancelled");
    expect(STATE.PAUSED).toBe("paused");
  });
});

describe("validateFile", () => {
  const config = {
    maxSizeBytes: 500 * 1024 * 1024,
    blockedExtensions: [".exe", ".bat", ".cmd"],
  };

  function fakeFile(name, size) {
    return { name, size };
  }

  it("accepts a valid file under size limit", () => {
    const result = validateFile(fakeFile("doc.pdf", 1024), config);
    expect(result).toEqual({ valid: true });
  });

  it("accepts a file exactly at size limit (boundary)", () => {
    const result = validateFile(fakeFile("big.zip", 500 * 1024 * 1024), config);
    expect(result).toEqual({ valid: true });
  });

  it("rejects a file over size limit", () => {
    const result = validateFile(fakeFile("huge.zip", 500 * 1024 * 1024 + 1), config);
    expect(result.valid).toBe(false);
    expect(result.error).toContain("500");
  });

  it("rejects a file with blocked extension", () => {
    const result = validateFile(fakeFile("virus.exe", 1024), config);
    expect(result.valid).toBe(false);
    expect(result.error).toContain(".exe");
  });

  it("rejects blocked extension case-insensitively", () => {
    const result = validateFile(fakeFile("script.BAT", 1024), config);
    expect(result.valid).toBe(false);
    expect(result.error).toContain(".bat");
  });

  it("accepts a file with no extension", () => {
    const result = validateFile(fakeFile("Makefile", 1024), config);
    expect(result).toEqual({ valid: true });
  });

  it("checks only the last extension", () => {
    const result = validateFile(fakeFile("archive.tar.gz", 1024), config);
    expect(result).toEqual({ valid: true });
  });
});

describe("encodeControlMessage / decodeMessage", () => {
  it("round-trips a control message", () => {
    const payload = { transferId: "abc-123", fileName: "test.pdf" };
    const encoded = encodeControlMessage(MSG.FILE_OFFER, payload);
    expect(encoded).toBeInstanceOf(ArrayBuffer);

    const decoded = decodeMessage(encoded);
    expect(decoded.type).toBe(MSG.FILE_OFFER);
    expect(decoded.payload).toEqual(payload);
  });

  it("round-trips all control message types", () => {
    for (const type of [
      MSG.FILE_OFFER,
      MSG.FILE_ACCEPT,
      MSG.FILE_REJECT,
      MSG.CANCEL,
      MSG.TRANSFER_DONE,
      MSG.HASH_RESULT,
      MSG.RETRY,
    ]) {
      const payload = { transferId: "test" };
      const decoded = decodeMessage(encodeControlMessage(type, payload));
      expect(decoded.type).toBe(type);
      expect(decoded.payload.transferId).toBe("test");
    }
  });
});

describe("encodeChunk / decodeMessage (chunk)", () => {
  it("round-trips a data chunk", () => {
    const data = new Uint8Array([1, 2, 3, 4, 5]).buffer;
    const encoded = encodeChunk(42, data);
    expect(encoded).toBeInstanceOf(ArrayBuffer);

    const decoded = decodeMessage(encoded);
    expect(decoded.type).toBe(MSG.CHUNK);
    expect(decoded.chunkIndex).toBe(42);
    expect(new Uint8Array(decoded.payload)).toEqual(new Uint8Array([1, 2, 3, 4, 5]));
  });

  it("handles chunk index 0", () => {
    const data = new Uint8Array([10]).buffer;
    const decoded = decodeMessage(encodeChunk(0, data));
    expect(decoded.chunkIndex).toBe(0);
  });

  it("handles large chunk index", () => {
    const data = new Uint8Array([10]).buffer;
    const decoded = decodeMessage(encodeChunk(7812, data));
    expect(decoded.chunkIndex).toBe(7812);
  });
});

describe("computeHash", () => {
  let originalDigest;

  beforeEach(() => {
    originalDigest = crypto.subtle.digest;
  });

  afterEach(() => {
    crypto.subtle.digest = originalDigest;
  });

  it("returns hex-encoded SHA-256 hash", async () => {
    const mockDigest = new Uint8Array([
      0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea, 0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22,
      0x23, 0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c, 0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00,
      0x15, 0xad,
    ]).buffer;

    crypto.subtle.digest = vi.fn().mockResolvedValue(mockDigest);

    const buffer = new ArrayBuffer(3);
    const result = await computeHash(buffer);
    expect(result).toBe("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
    expect(crypto.subtle.digest).toHaveBeenCalledWith("SHA-256", new Uint8Array(buffer));
  });
});

describe("formatFileSize", () => {
  it("formats bytes", () => {
    expect(formatFileSize(500)).toBe("500 B");
  });

  it("formats kilobytes", () => {
    expect(formatFileSize(1536)).toBe("1.5 KB");
  });

  it("formats megabytes", () => {
    expect(formatFileSize(2516582)).toBe("2.4 MB");
  });

  it("formats gigabytes", () => {
    expect(formatFileSize(1073741824)).toBe("1.0 GB");
  });

  it("formats zero", () => {
    expect(formatFileSize(0)).toBe("0 B");
  });
});

describe("formatSpeed", () => {
  it("formats bytes per second", () => {
    expect(formatSpeed(500)).toBe("500 B/s");
  });

  it("formats KB/s", () => {
    expect(formatSpeed(350 * 1024)).toBe("350.0 KB/s");
  });

  it("formats MB/s", () => {
    expect(formatSpeed(2.5 * 1024 * 1024)).toBe("2.5 MB/s");
  });

  it("formats zero speed", () => {
    expect(formatSpeed(0)).toBe("0 B/s");
  });
});

describe("formatEta", () => {
  it("formats seconds only", () => {
    expect(formatEta(45)).toBe("45s");
  });

  it("formats minutes and seconds", () => {
    expect(formatEta(135)).toBe("2m 15s");
  });

  it("formats hours", () => {
    expect(formatEta(3661)).toBe("1h 1m 1s");
  });

  it("formats zero", () => {
    expect(formatEta(0)).toBe("0s");
  });

  it("handles Infinity", () => {
    expect(formatEta(Infinity)).toBe("--");
  });
});

// --- Phase 3: User Story 1 Tests (T014-T015) ---

describe("createSenderSession", () => {
  it("creates a sender session with correct fields", () => {
    const file = { name: "test.pdf", size: 131072, type: "application/pdf" };
    const session = createSenderSession(file, "abc123hash");

    expect(session.role).toBe("sender");
    expect(session.state).toBe(STATE.OFFERING);
    expect(session.file).toBe(file);
    expect(session.fileName).toBe("test.pdf");
    expect(session.fileSize).toBe(131072);
    expect(session.mimeType).toBe("application/pdf");
    expect(session.totalChunks).toBe(Math.ceil(131072 / CHUNK_SIZE));
    expect(session.expectedHash).toBe("abc123hash");
    expect(session.transferId).toBeTruthy();
    expect(session.bytesSent).toBe(0);
    expect(session.speedSamples).toEqual([]);
  });
});

describe("createReceiverSession", () => {
  it("creates a receiver session from an offer", () => {
    const offer = {
      transferId: "test-id",
      fileName: "doc.pdf",
      fileSize: 65536,
      mimeType: "application/pdf",
      totalChunks: 1,
      sha256: "hash123",
    };
    const session = createReceiverSession(offer);

    expect(session.role).toBe("receiver");
    expect(session.state).toBe(STATE.TRANSFERRING);
    expect(session.transferId).toBe("test-id");
    expect(session.fileName).toBe("doc.pdf");
    expect(session.fileSize).toBe(65536);
    expect(session.totalChunks).toBe(1);
    expect(session.expectedHash).toBe("hash123");
    expect(session.chunks).toHaveLength(1);
    expect(session.receivedSet).toBeInstanceOf(Set);
    expect(session.receivedSet.size).toBe(0);
    expect(session.bytesReceived).toBe(0);
  });
});

describe("getNextChunk", () => {
  it("returns chunks sequentially from a file", async () => {
    const data = new Uint8Array(CHUNK_SIZE + 100);
    data.fill(42);
    const file = {
      name: "test.bin",
      size: data.length,
      type: "application/octet-stream",
      slice(start, end) {
        const sliced = data.slice(start, end);
        return {
          arrayBuffer() {
            return Promise.resolve(
              sliced.buffer.slice(sliced.byteOffset, sliced.byteOffset + sliced.byteLength),
            );
          },
        };
      },
    };

    const session = createSenderSession(file, "hash");
    session.state = STATE.TRANSFERRING;

    const chunk0 = await getNextChunk(session);
    expect(chunk0.index).toBe(0);
    expect(chunk0.data.byteLength).toBe(CHUNK_SIZE);

    const chunk1 = await getNextChunk(session);
    expect(chunk1.index).toBe(1);
    expect(chunk1.data.byteLength).toBe(100);

    const done = await getNextChunk(session);
    expect(done).toBeNull();
  });
});

describe("receiveChunk", () => {
  it("stores a chunk in the correct index", () => {
    const offer = {
      transferId: "t1",
      fileName: "f.bin",
      fileSize: CHUNK_SIZE * 2,
      mimeType: "application/octet-stream",
      totalChunks: 2,
      sha256: "h",
    };
    const session = createReceiverSession(offer);
    const data = new ArrayBuffer(10);

    receiveChunk(session, 1, data);
    expect(session.receivedSet.has(1)).toBe(true);
    expect(session.chunks[1]).toBe(data);
    expect(session.bytesReceived).toBe(10);
  });

  it("ignores duplicate chunks", () => {
    const offer = {
      transferId: "t1",
      fileName: "f.bin",
      fileSize: CHUNK_SIZE * 2,
      mimeType: "application/octet-stream",
      totalChunks: 2,
      sha256: "h",
    };
    const session = createReceiverSession(offer);
    const data1 = new ArrayBuffer(10);
    const data2 = new ArrayBuffer(5);

    receiveChunk(session, 0, data1);
    receiveChunk(session, 0, data2);
    expect(session.bytesReceived).toBe(10);
    expect(session.chunks[0]).toBe(data1);
  });
});

describe("assembleFile", () => {
  it("creates a Blob from received chunks in order", () => {
    const offer = {
      transferId: "t1",
      fileName: "f.bin",
      fileSize: 6,
      mimeType: "application/octet-stream",
      totalChunks: 2,
      sha256: "h",
    };
    const session = createReceiverSession(offer);

    receiveChunk(session, 0, new Uint8Array([1, 2, 3]).buffer);
    receiveChunk(session, 1, new Uint8Array([4, 5, 6]).buffer);

    const blob = assembleFile(session);
    expect(blob).toBeInstanceOf(Blob);
    expect(blob.size).toBe(6);
    expect(blob.type).toBe("application/octet-stream");
  });
});

describe("cleanupSession", () => {
  it("nullifies session fields to free memory", () => {
    const offer = {
      transferId: "t1",
      fileName: "f.bin",
      fileSize: 100,
      mimeType: "application/octet-stream",
      totalChunks: 1,
      sha256: "h",
    };
    const session = createReceiverSession(offer);
    receiveChunk(session, 0, new ArrayBuffer(100));

    cleanupSession(session);
    expect(session.chunks).toBeNull();
    expect(session.file).toBeNull();
    expect(session.receivedSet).toBeNull();
    expect(session.state).toBe(STATE.IDLE);
  });
});

describe("calculateProgress", () => {
  it("calculates percentage for sender", () => {
    const file = { name: "t.bin", size: CHUNK_SIZE * 10, type: "application/octet-stream" };
    const session = createSenderSession(file, "h");
    session.state = STATE.TRANSFERRING;
    session.bytesSent = CHUNK_SIZE * 3;
    session.startTime = Date.now() - 1000;

    const progress = calculateProgress(session);
    expect(progress.percent).toBe(30);
  });

  it("calculates percentage for receiver", () => {
    const offer = {
      transferId: "t1",
      fileName: "f.bin",
      fileSize: CHUNK_SIZE * 4,
      mimeType: "application/octet-stream",
      totalChunks: 4,
      sha256: "h",
    };
    const session = createReceiverSession(offer);
    session.bytesReceived = CHUNK_SIZE * 2;
    session.startTime = Date.now() - 1000;

    const progress = calculateProgress(session);
    expect(progress.percent).toBe(50);
  });
});

describe("recordSpeedSample", () => {
  it("adds speed samples", () => {
    const file = { name: "t.bin", size: CHUNK_SIZE * 10, type: "application/octet-stream" };
    const session = createSenderSession(file, "h");

    const t0 = 1000;
    recordSpeedSample(session, CHUNK_SIZE, t0);
    recordSpeedSample(session, CHUNK_SIZE * 2, t0 + 500);

    expect(session.speedSamples.length).toBe(2);
  });

  it("prunes samples older than SPEED_WINDOW_MS", () => {
    const file = { name: "t.bin", size: CHUNK_SIZE * 10, type: "application/octet-stream" };
    const session = createSenderSession(file, "h");

    const t0 = 1000;
    recordSpeedSample(session, CHUNK_SIZE, t0);
    recordSpeedSample(session, CHUNK_SIZE * 2, t0 + SPEED_WINDOW_MS + 100);

    expect(session.speedSamples.length).toBe(1);
  });
});

// --- Phase 5: User Story 3 Tests (T034) ---

describe("encodeHaveChunks / decodeHaveChunks", () => {
  it("round-trips have-chunks message", () => {
    const transferId = "abc-123-def";
    const indices = new Set([0, 1, 5, 10, 100]);

    const encoded = encodeHaveChunks(transferId, indices);
    expect(encoded).toBeInstanceOf(ArrayBuffer);

    const decoded = decodeHaveChunks(encoded);
    expect(decoded.transferId).toBe(transferId);
    expect(decoded.indices).toEqual(indices);
  });

  it("handles empty index set", () => {
    const encoded = encodeHaveChunks("tid", new Set());
    const decoded = decodeHaveChunks(encoded);
    expect(decoded.transferId).toBe("tid");
    expect(decoded.indices.size).toBe(0);
  });
});

describe("markChunksReceived", () => {
  it("advances nextChunkIndex past already-received chunks", () => {
    const file = {
      name: "t.bin",
      size: CHUNK_SIZE * 5,
      type: "application/octet-stream",
      slice() {
        return new Blob([new ArrayBuffer(CHUNK_SIZE)]);
      },
    };
    const session = createSenderSession(file, "h");
    session.state = STATE.TRANSFERRING;

    markChunksReceived(session, new Set([0, 1, 2]));
    expect(session.sentSet.has(0)).toBe(true);
    expect(session.sentSet.has(1)).toBe(true);
    expect(session.sentSet.has(2)).toBe(true);
  });
});

// --- Phase 6: User Story 4 Tests (T039) ---

describe("hash mismatch and retry", () => {
  it("decodes hash-result with match=false", () => {
    const msg = encodeControlMessage(MSG.HASH_RESULT, {
      transferId: "t1",
      match: false,
    });
    const decoded = decodeMessage(msg);
    expect(decoded.payload.match).toBe(false);
  });

  it("decodes retry message", () => {
    const msg = encodeControlMessage(MSG.RETRY, { transferId: "t1" });
    const decoded = decodeMessage(msg);
    expect(decoded.type).toBe(MSG.RETRY);
    expect(decoded.payload.transferId).toBe("t1");
  });
});

// --- Phase 7: User Story 5 Tests (T044) ---

describe("isTransferActive", () => {
  it("returns false for null session", () => {
    expect(isTransferActive(null)).toBe(false);
  });

  it("returns false for idle session", () => {
    expect(isTransferActive({ state: STATE.IDLE })).toBe(false);
  });

  it("returns true for transferring session", () => {
    expect(isTransferActive({ state: STATE.TRANSFERRING })).toBe(true);
  });

  it("returns true for offering session", () => {
    expect(isTransferActive({ state: STATE.OFFERING })).toBe(true);
  });

  it("returns true for verifying session", () => {
    expect(isTransferActive({ state: STATE.VERIFYING })).toBe(true);
  });

  it("returns false for completed session", () => {
    expect(isTransferActive({ state: STATE.COMPLETED })).toBe(false);
  });

  it("returns false for cancelled session", () => {
    expect(isTransferActive({ state: STATE.CANCELLED })).toBe(false);
  });
});

describe("createQueueEntry", () => {
  it("creates a queue entry with file and timestamp", () => {
    const file = { name: "queued.pdf", size: 1024, type: "application/pdf" };
    const entry = createQueueEntry(file);

    expect(entry.file).toBe(file);
    expect(typeof entry.queuedAt).toBe("number");
    expect(entry.queuedAt).toBeGreaterThan(0);
  });
});
