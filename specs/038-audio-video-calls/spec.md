# Feature Specification: Audio/Video Calls

**Feature Branch**: `038-audio-video-calls`
**Created**: 2026-02-16
**Status**: Draft
**Input**: User description: "Audio/Video Calls for RetroHexChat — P2P audio and video calling over WebRTC"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Audio Call (Priority: P1)

Two peers in a P2P lobby initiate an audio call. After bilateral consent and microphone permission grants, both users hear each other through a direct peer-to-peer connection. The call UI shows peer name, call duration timer, mute button, and call quality indicator. Either peer can mute/unmute their microphone at any time, with the other peer seeing a visual notification. Either peer can end the call.

**Why this priority**: Audio calling is the foundational media feature — it requires the complete media pipeline (permission handling, track management, UI controls) and is the simplest call type. All other stories build on this.

**Independent Test**: Two peers accept an audio call, speak to each other, one mutes, the other sees the mute indicator, then one ends the call. Both return to the lobby.

**Acceptance Scenarios**:

1. **Given** two peers in an active P2P lobby, **When** one clicks 'Chamada de Audio' and the other accepts, **Then** both browsers request microphone permission and audio flows between them.
2. **Given** an active audio call, **When** one peer clicks the mute button, **Then** their microphone is silenced and the other peer sees a notification "[nickname] silenciou o microfone".
3. **Given** an active audio call, **When** one peer clicks 'Encerrar Chamada', **Then** the call ends for both peers, media tracks are stopped, and both return to the lobby view.
4. **Given** an active audio call, **When** the call has been running for 15 seconds, **Then** both peers see a duration timer displaying "00:00:15".
5. **Given** an active audio call, **When** network quality is good, **Then** the quality indicator shows 4 green bars.
6. **Given** a microphone permission request, **When** the user denies permission, **Then** a friendly error message is shown and the call does not proceed.

---

### User Story 2 - Video Call (Priority: P2)

Two peers initiate a video call. After consent and camera+microphone permission grants, both cameras and microphones activate. The layout displays the remote peer's video large (filling the call area) and the local user's video small in the bottom-right corner (picture-in-picture style). Audio and video flow simultaneously. Both users can toggle their camera on/off during the call.

**Why this priority**: Video calling adds the visual dimension and introduces the video layout (remote large + local small), camera toggle, and video track management. It depends on the audio call pipeline from US1.

**Independent Test**: Two peers accept a video call, see each other's video, one toggles camera off (the other sees a placeholder), then the call is ended.

**Acceptance Scenarios**:

1. **Given** two peers in an active P2P lobby, **When** one clicks 'Chamada de Video' and the other accepts, **Then** both browsers request camera and microphone permissions and video+audio flows between them.
2. **Given** an active video call, **When** the layout renders, **Then** the remote peer's video is displayed large and the local user's video is displayed small in the bottom-right corner.
3. **Given** an active video call, **When** one peer toggles their camera off, **Then** their video track stops, the other peer sees a placeholder (peer name or avatar icon), and audio continues.
4. **Given** an active video call, **When** one peer toggles their camera back on, **Then** their video track resumes and the other peer sees their video again.
5. **Given** a video call request, **When** the user has no camera available, **Then** a friendly error is shown offering to proceed as an audio-only call.
6. **Given** an active video call, **When** the local video element renders, **Then** it is muted to prevent audio feedback loops.

---

### User Story 3 - Call Quality Monitoring and Manual Adjustment (Priority: P3)

During any active call, both peers see a quality indicator with 4 levels (Excellent, Good, Fair, Poor) based on connection statistics. Users can manually adjust call quality by selecting a bitrate preset (High, Medium, Low) to improve stability on poor connections. Quality statistics are polled periodically and the indicator updates in real time.

**Why this priority**: Quality monitoring provides essential feedback during calls and manual adjustment gives users control when automatic adaptation is not sufficient. This builds on the active call from US1/US2.

**Independent Test**: During an active call, observe the quality indicator updating. Select "Low" quality preset and verify the bitrate limit is applied.

**Acceptance Scenarios**:

1. **Given** an active call, **When** connection quality is excellent (low latency, no packet loss), **Then** the quality indicator shows 4 green bars labeled "Excelente".
2. **Given** an active call, **When** connection quality degrades (moderate packet loss), **Then** the quality indicator updates to 3 bars labeled "Bom", then 2 bars labeled "Regular", or 1 bar labeled "Ruim" as conditions worsen.
3. **Given** an active call with poor quality, **When** the user selects "Baixa" quality preset, **Then** the maximum bitrate is reduced and the UI confirms the change.
4. **Given** an active call, **When** quality statistics are polled, **Then** the indicator updates within 3 seconds of a quality change.

---

### User Story 4 - Audio-to-Video Upgrade (Priority: P4)

During an active audio call, either peer can request to upgrade to a video call. The other peer must accept the upgrade request. Upon acceptance, the requesting peer's camera activates, the video track is added to the connection, and the layout transitions from audio-only to the video layout (remote large + local small). If the upgrade is rejected, the call continues as audio-only.

**Why this priority**: Mid-call upgrade is a power-user feature that requires renegotiation of the peer connection. It enhances flexibility but is not essential for basic calling.

**Independent Test**: Start an audio call, request video upgrade, peer accepts, verify video appears for both. Then repeat with rejection and verify audio continues unchanged.

**Acceptance Scenarios**:

1. **Given** an active audio call, **When** one peer clicks 'Adicionar Video', **Then** the other peer sees a request to upgrade to video with Accept/Reject buttons.
2. **Given** an upgrade request, **When** the peer accepts, **Then** the requesting peer's camera activates, video track is added, and both peers transition to the video call layout.
3. **Given** an upgrade request, **When** the peer rejects, **Then** the call continues as audio-only and the requester sees a notification that the upgrade was declined.
4. **Given** an upgrade in progress, **When** camera permission is denied, **Then** the call remains audio-only and a friendly error is shown.

---

### User Story 5 - Device Selection and Change Detection (Priority: P5)

Users can select their preferred audio input (microphone), audio output (speaker/headphone), and video input (camera) from available devices during an active call. When a device is disconnected mid-call (e.g., unplugging a USB headset), the system automatically falls back to the default device and notifies the user.

**Why this priority**: Device management is important for a polished experience but requires the full media pipeline from US1/US2 to be working first.

**Independent Test**: During an active call, change the microphone selection and verify audio switches. Simulate device disconnection and verify fallback to default.

**Acceptance Scenarios**:

1. **Given** an active call, **When** the user opens device settings, **Then** a list of available audio input, audio output, and video input devices is shown.
2. **Given** an active call with device settings open, **When** the user selects a different microphone, **Then** the audio input switches to the selected device without interrupting the call.
3. **Given** an active call, **When** the active microphone is disconnected, **Then** the system falls back to the default microphone and shows "Dispositivo desconectado, usando dispositivo padrao".
4. **Given** a browser that does not support audio output selection, **When** the user opens device settings, **Then** the audio output selector is hidden and the system uses the default output.

---

### User Story 6 - Browser Picture-in-Picture (Priority: P6)

During a video call, users can activate the browser's native Picture-in-Picture mode for the remote video. This pops the video out into a floating window that stays visible even when the user switches to other browser tabs or applications. If the browser does not support PiP, the button is hidden.

**Why this priority**: PiP is a convenience feature that leverages native browser capabilities. It is non-essential but significantly improves multitasking during video calls.

**Independent Test**: During a video call, click the PiP button and verify the remote video enters Picture-in-Picture mode. Switch tabs and verify the video remains visible.

**Acceptance Scenarios**:

1. **Given** an active video call in a browser that supports PiP, **When** the user clicks the PiP button, **Then** the remote video enters Picture-in-Picture mode in a floating window.
2. **Given** the remote video in PiP mode, **When** the user switches to another browser tab, **Then** the PiP window remains visible.
3. **Given** a browser that does not support PiP, **When** the video call layout renders, **Then** the PiP button is not shown.
4. **Given** the remote video in PiP mode, **When** the user exits PiP or ends the call, **Then** the PiP window closes and the video returns to the normal layout.

---

### Edge Cases

- **Camera in use by another application**: The user sees "Camera em uso por outro aplicativo. Tente fechar outros programas que usam a camera." (NotReadableError).
- **No camera available for video call**: The user sees "Nenhuma camera encontrada." with an option to proceed as audio-only (NotFoundError).
- **Both peers mute simultaneously**: Both see the other's muted indicator — no conflict.
- **Device disconnected during call**: Auto-fallback to default device with notification.
- **PiP not supported**: PiP button is hidden; no error shown.
- **Very poor network quality**: Quality indicator shows 1 bar ("Ruim"). The system's built-in bandwidth adaptation reduces resolution and framerate automatically.
- **Audio-to-video upgrade rejected**: Call remains audio-only; requester is notified.
- **Browser tab backgrounded**: Video may pause (browser behavior); audio continues unaffected.
- **setSinkId not supported**: Audio output selector is hidden; system default is used.
- **Microphone permission denied**: Friendly message "Permissao de microfone negada. A chamada nao pode continuar." Call does not start.
- **Camera permission denied during video call**: Friendly message offering audio-only fallback.
- **Peer disconnects during call**: Call ends, tracks are stopped, user sees "Peer desconectou".

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow users to initiate audio calls from the P2P lobby after bilateral consent.
- **FR-002**: System MUST allow users to initiate video calls from the P2P lobby after bilateral consent.
- **FR-003**: System MUST request microphone permission before starting an audio call and both microphone and camera permissions before starting a video call.
- **FR-004**: System MUST display friendly, localized error messages for all permission denial scenarios (NotAllowedError, NotReadableError, NotFoundError).
- **FR-005**: System MUST add audio tracks (and video tracks for video calls) to the existing peer connection established by the signaling layer.
- **FR-006**: System MUST provide a mute/unmute toggle for the microphone during any active call.
- **FR-007**: System MUST notify the remote peer when the local user mutes or unmutes their microphone.
- **FR-008**: System MUST provide a camera on/off toggle during video calls.
- **FR-009**: System MUST display the remote peer's video in a large view and the local user's video in a small overlay (bottom-right corner) during video calls.
- **FR-010**: Local video element MUST be muted to prevent audio feedback loops.
- **FR-011**: System MUST display a call duration timer (HH:MM:SS format) during active calls.
- **FR-012**: System MUST display a 4-level quality indicator (Excellent/Good/Fair/Poor) based on connection statistics during active calls.
- **FR-013**: System MUST allow users to manually select a quality preset (High, Medium, Low) that adjusts the maximum bitrate.
- **FR-014**: System MUST allow upgrading from audio-only to video during an active call, requiring the remote peer's consent.
- **FR-015**: System MUST handle upgrade rejection by continuing the current audio-only call without disruption.
- **FR-016**: System MUST enumerate and display available audio input, audio output, and video input devices during an active call.
- **FR-017**: System MUST allow switching to a different device mid-call without interrupting the call.
- **FR-018**: System MUST detect device disconnection and automatically fall back to the default device, notifying the user.
- **FR-019**: System MUST hide audio output selection when the browser does not support setSinkId.
- **FR-020**: System MUST provide a Picture-in-Picture button during video calls that activates the browser's native PiP for the remote video.
- **FR-021**: System MUST hide the PiP button when the browser does not support Picture-in-Picture.
- **FR-022**: System MUST stop all media tracks and clean up resources when a call ends (user-initiated or peer disconnect).
- **FR-023**: System MUST send all media exclusively through the peer-to-peer connection — no media data may pass through the server.
- **FR-024**: System MUST prefer specific codecs (H.264 over VP8 for video, Opus for audio) when available.
- **FR-025**: System MUST separate media logic (pure functions, no DOM) from hook wiring (DOM events, no media logic).
- **FR-026**: System MUST offer an audio-only fallback when no camera is available for a requested video call.

### Key Entities

- **Call Session**: Represents an active audio or video call between two peers. Key attributes: call type (audio/video), start time, mute states for both peers, camera states for both peers, quality level, active quality preset.
- **Media Track**: Represents an audio or video track from a local device. Key attributes: track kind (audio/video), device ID, enabled state, muted state.
- **Device Info**: Represents an available media device. Key attributes: device ID, device kind (audioinput/audiooutput/videoinput), label.
- **Quality Snapshot**: A periodic sample of connection health. Key attributes: round-trip time, packet loss percentage, available bandwidth, jitter. Maps to one of 4 quality levels.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can complete an audio call setup (click 'Chamada de Audio' to hearing peer's voice) in under 5 seconds after both peers accept.
- **SC-002**: Users can complete a video call setup (click 'Chamada de Video' to seeing peer's video) in under 8 seconds after both peers accept.
- **SC-003**: Call duration timer is accurate to within 1 second over a 10-minute call.
- **SC-004**: Quality indicator updates within 3 seconds of a connection quality change.
- **SC-005**: Mute/unmute and camera toggle take effect within 500 milliseconds of user action.
- **SC-006**: Device switching completes without call interruption and audio/video resumes within 2 seconds.
- **SC-007**: Audio-to-video upgrade completes within 5 seconds of both peers accepting.
- **SC-008**: All permission errors display user-friendly messages in Portuguese with clear next-step guidance.
- **SC-009**: Device disconnection fallback activates within 3 seconds with user notification.
- **SC-010**: 100% of media data flows peer-to-peer — zero bytes through the server.

## Assumptions

- The existing WebRTC signaling infrastructure (036) provides a stable RTCPeerConnection before media tracks are added.
- The existing P2P lobby bilateral consent flow handles the initial call request/accept/reject interaction.
- Browser echo cancellation is enabled by default via getUserMedia constraints (echoCancellation: true).
- The browser handles codec negotiation natively; codec preferences are set as hints, not hard requirements.
- Call duration is measured client-side and does not need server synchronization.
- Quality statistics are obtained via getStats() on the peer connection, which is widely supported.
- Device enumeration requires an active permission grant to show device labels.
- Video resolution defaults to 640x480 for standard quality, with the browser adapting as needed.
- Audio-to-video upgrade uses the existing signaling renegotiation mechanism (offer/answer exchange).

## Scope

### In Scope

- media.js pure logic library (track management, device enumeration, quality metrics, codec preferences)
- media_hook.js LiveView hook (DOM wiring, video elements, UI controls)
- Audio call initiation, UI, and controls
- Video call initiation, layout (remote large + local PiP), and controls
- Permission error handling with localized messages
- Mute/unmute microphone and camera toggle
- Device selection mid-call (audio input, audio output, video input)
- Audio-to-video upgrade with renegotiation
- Call duration timer (HH:MM:SS)
- 4-level quality indicator with manual quality adjustment (High/Medium/Low bitrate presets)
- Browser-native Picture-in-Picture for remote video
- Device change detection and automatic fallback
- Codec preferences (H.264 > VP8, Opus)
- JavaScript unit tests

### Out of Scope

- Screen sharing
- Recording
- Multi-party calls (only 1-to-1)
- Virtual backgrounds or filters
- TURN server setup (uses existing infrastructure)
- Help documentation
