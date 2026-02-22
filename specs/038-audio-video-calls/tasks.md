# Tasks: Audio/Video Calls

**Input**: Design documents from `/specs/038-audio-video-calls/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Yes — spec.md scope includes "JS tests" and constitution requires TDD (Principle IV).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Umbrella web app**: `apps/retro_hex_chat_web/assets/` for JS/CSS, `apps/retro_hex_chat_web/lib/` for Elixir
- Test files: `apps/retro_hex_chat_web/assets/test/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the media.js lib module and MediaHook skeleton, register hook, import CSS

- [X] T001 Create `apps/retro_hex_chat_web/assets/js/lib/media.js` with module skeleton: exports for acquireMedia, getAudioConstraints, getVideoConstraints, addMediaTracks, removeMediaTracks, toggleTrack, replaceTrack, stopAllTracks, enumerateDevices, switchAudioInput, switchVideoInput, setSinkId, supportsSetSinkId, getQualitySnapshot, mapQualityLevel, applyBitratePreset, BITRATE_PRESETS, setCodecPreferences, formatDuration, supportsPiP, togglePiP, categorizeMediaError, QUALITY_LABELS
- [X] T002 Create `apps/retro_hex_chat_web/assets/js/hooks/media_hook.js` with hook skeleton: mounted(), destroyed(), handleEvent registrations for media_start_audio, media_start_video, media_end_call, media_peer_muted, media_peer_camera, media_upgrade_accepted, media_upgrade_rejected, media_set_preset. Listen for media_pc_ready/media_pc_closed CustomEvents
- [X] T003 [P] Register MediaHook in `apps/retro_hex_chat_web/assets/js/app.js` — import and add to Hooks object
- [X] T004 [P] Create `apps/retro_hex_chat_web/assets/css/media-call.css` with empty file and class stubs for .media-call, .media-call__remote, .media-call__local, .media-call__controls, .media-call__timer, .media-call__quality
- [X] T005 [P] Add `@import "./media-call.css"` to `apps/retro_hex_chat_web/assets/css/app.css` in Layer 4 Components (alphabetical: after loading-spinner.css, before nicklist.css)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T006 Implement media acquisition functions in `apps/retro_hex_chat_web/assets/js/lib/media.js`: acquireMedia(constraints) wrapping getUserMedia with error categorization, getAudioConstraints() returning {echoCancellation: true, noiseSuppression: true}, getVideoConstraints() returning {width: {ideal: 640}, height: {ideal: 480}, facingMode: "user"}, categorizeMediaError(error) mapping NotAllowedError/NotReadableError/NotFoundError to localized Portuguese messages
- [X] T007 Implement track management functions in `apps/retro_hex_chat_web/assets/js/lib/media.js`: addMediaTracks(pc, stream) returning RTCRtpSender[], removeMediaTracks(pc, senders), toggleTrack(stream, kind, enabled) returning boolean, replaceTrack(sender, newTrack), stopAllTracks(stream)
- [X] T008 Implement formatDuration(startTime) in `apps/retro_hex_chat_web/assets/js/lib/media.js` returning HH:MM:SS string from Date.now() start time
- [X] T009 [P] Write unit tests for media acquisition in `apps/retro_hex_chat_web/assets/test/lib/media.test.js`: test acquireMedia success, test categorizeMediaError for NotAllowedError/NotReadableError/NotFoundError/unknown, test getAudioConstraints, test getVideoConstraints
- [X] T010 [P] Write unit tests for track management in `apps/retro_hex_chat_web/assets/test/lib/media.test.js`: test addMediaTracks, test toggleTrack, test stopAllTracks, test formatDuration for various durations (0s, 15s, 65s, 3661s)
- [X] T011 Modify `apps/retro_hex_chat_web/assets/js/hooks/webrtc_hook.js`: in _handleConnectionStateChange "connected" case, dispatch CustomEvent "media_pc_ready" with {pc: this.pc} on this.el. In _cleanup, dispatch "media_pc_closed". Add pc.onnegotiationneeded handler that creates a new offer and sends via p2p_signal pushEvent (for renegotiation support)
- [X] T012 Add call-related assigns and event handlers skeleton to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_session_live.ex`: add `call: nil` to socket assigns, add handle_event stubs for media_call_started, media_call_ended, media_error, media_mute_changed, media_camera_changed, media_quality_update, media_request_upgrade, media_respond_upgrade, media_duration_tick, media_device_fallback, media_select_preset
- [X] T013 Add call UI container to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/p2p_lobby.ex`: add `call` attr, add `<.p2p_media_call>` component that renders when @call is not nil with id="media-call" phx-hook="MediaHook", video/audio elements, and basic control buttons (mute, end call)

**Checkpoint**: Foundation ready — media.js core functions tested, hook skeleton registered, WebRTCHook dispatches PC to MediaHook, LiveView has call assigns

---

## Phase 3: User Story 1 — Audio Call (Priority: P1) 🎯 MVP

**Goal**: Two peers initiate an audio call, hear each other, mute/unmute, see duration timer and quality indicator, end call

**Independent Test**: Two peers accept audio call, speak, one mutes (other sees indicator), one ends call, both return to lobby

### Tests for User Story 1

- [X] T014 [P] [US1] Write media_hook.js tests for audio call flow in `apps/retro_hex_chat_web/assets/test/hooks/media_hook.test.js`: test mounted registers event listeners, test media_start_audio calls acquireMedia with audio constraints and addMediaTracks, test media_end_call stops tracks and pushes media_call_ended, test mute button toggles track and pushes media_mute_changed, test media_peer_muted updates remote mute indicator, test duration timer ticks every second

### Implementation for User Story 1

- [X] T015 [US1] Implement audio call start in `apps/retro_hex_chat_web/assets/js/hooks/media_hook.js`: on media_start_audio handleEvent, call acquireMedia({audio: getAudioConstraints()}), addMediaTracks(pc, stream), store stream and senders, set up ontrack handler to attach remote stream to #remote-audio element, start duration timer interval (1s), pushEvent media_call_started with type "audio"
- [X] T016 [US1] Implement mute toggle in `apps/retro_hex_chat_web/assets/js/hooks/media_hook.js`: wire mute button click to toggleTrack(stream, "audio", !muted), pushEvent media_mute_changed with muted state. Handle media_peer_muted to update remote mute indicator DOM
- [X] T017 [US1] Implement call end in `apps/retro_hex_chat_web/assets/js/hooks/media_hook.js`: on media_end_call handleEvent or end-call button click, call stopAllTracks, removeMediaTracks, clear duration timer interval, pushEvent media_call_ended. On destroyed() also clean up
- [X] T018 [US1] Implement audio call LiveView handlers in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_session_live.ex`: handle_event media_call_started sets call assign, handle_event media_call_ended clears call assign and adds system message. handle_event media_mute_changed broadcasts {:media_mute, muted} via PubSub. handle_info {:media_mute, muted} pushes media_peer_muted to hook. handle_event media_duration_tick updates call.duration assign
- [X] T019 [US1] Implement consent flow integration in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_session_live.ex`: after action "audio_call" accepted, push_event "media_start_audio" to hook. Wire the existing respond_action handler to trigger media start
- [X] T020 [US1] Implement audio call UI components in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/p2p_lobby.ex`: p2p_media_call component with audio layout showing peer name, mute button (with muted/unmuted state), duration timer display (@call.duration), remote mute indicator ("[peer] silenciou o microfone"), end call button ("Encerrar Chamada")
- [X] T021 [US1] Style audio call UI in `apps/retro_hex_chat_web/assets/css/media-call.css`: .media-call container, .media-call__controls with mute and end-call buttons using retro button styles, .media-call__timer with monospace font, .media-call__info with peer name, .media-call__mute-indicator for remote mute notification, .media-call__btn--active for toggled mute state
- [X] T022 [US1] Handle permission errors in `apps/retro_hex_chat_web/assets/js/hooks/media_hook.js`: if acquireMedia rejects, pushEvent media_error with categorized error code and localized message. LiveView shows error and does not proceed with call

**Checkpoint**: Audio calls fully functional — peers can call, hear each other, mute/unmute, see timer, end call

---

## Phase 4: User Story 2 — Video Call (Priority: P2)

**Goal**: Two peers initiate a video call with remote video large and local video small (PiP style), camera toggle

**Independent Test**: Two peers accept video call, see each other's video, one toggles camera off (placeholder shown), call ended

### Tests for User Story 2

- [X] T023 [P] [US2] Write media.test.js tests for video-specific functions in `apps/retro_hex_chat_web/assets/test/lib/media.test.js`: test acquireMedia with video+audio constraints, test toggleTrack for video kind
- [X] T024 [P] [US2] Write media_hook.js tests for video call in `apps/retro_hex_chat_web/assets/test/hooks/media_hook.test.js`: test media_start_video calls acquireMedia with video+audio, test ontrack attaches remote stream to #remote-video, test local video is muted, test camera toggle pushes media_camera_changed

### Implementation for User Story 2

- [X] T025 [US2] Implement video call start in `apps/retro_hex_chat_web/assets/js/hooks/media_hook.js`: on media_start_video handleEvent, call acquireMedia({audio: getAudioConstraints(), video: getVideoConstraints()}), addMediaTracks, set up ontrack to attach remote video to #remote-video and local video to #local-video (muted attribute), start duration timer, pushEvent media_call_started with type "video". Handle no-camera error with audio-only fallback offer
- [X] T026 [US2] Implement camera toggle in `apps/retro_hex_chat_web/assets/js/hooks/media_hook.js`: wire camera button click to toggleTrack(stream, "video", !off), pushEvent media_camera_changed. Handle media_peer_camera to show/hide remote video placeholder
- [X] T027 [US2] Implement video call LiveView handlers in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_session_live.ex`: handle_event media_camera_changed broadcasts {:media_camera, off} via PubSub. handle_info {:media_camera, off} pushes media_peer_camera to hook. Wire "video_call" consent acceptance to push_event "media_start_video"
- [X] T028 [US2] Add video layout to call UI in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/p2p_lobby.ex`: update p2p_media_call component — when call.type == "video", render #remote-video (large, autoplay, playsinline) and #local-video (small bottom-right, autoplay, playsinline, muted). Add camera toggle button. Show placeholder with peer name when peer camera is off
- [X] T029 [US2] Style video layout in `apps/retro_hex_chat_web/assets/css/media-call.css`: .media-call--video layout with CSS grid, .media-call__remote filling container, .media-call__local positioned bottom-right with smaller size and border, .media-call__placeholder centered text when camera off, camera toggle button styles

**Checkpoint**: Video calls work — remote large, local PiP, camera toggle, all audio controls from US1 still work

---

## Phase 5: User Story 3 — Call Quality Monitoring (Priority: P3)

**Goal**: 4-level quality indicator updates during calls, manual bitrate preset selection

**Independent Test**: During active call, observe quality indicator updating. Select "Low" preset, verify bitrate applied

### Tests for User Story 3

- [X] T030 [P] [US3] Write media.test.js tests for quality functions in `apps/retro_hex_chat_web/assets/test/lib/media.test.js`: test mapQualityLevel returns "excellent" for low loss/rtt, "good" for moderate, "fair" for higher, "poor" for worst. Test BITRATE_PRESETS values. Test applyBitratePreset calls setParameters on senders

### Implementation for User Story 3

- [X] T031 [US3] Implement quality monitoring in `apps/retro_hex_chat_web/assets/js/lib/media.js`: getQualitySnapshot(pc) polling getStats() and extracting roundTripTime, packetLoss, jitter from RTCInboundRtpStreamStats and RTCIceCandidatePairStats. mapQualityLevel(snapshot) with thresholds: excellent (loss<1%, rtt<100ms), good (loss<3%, rtt<200ms), fair (loss<8%, rtt<400ms), poor (else). QUALITY_LABELS map: {excellent: "Excelente", good: "Bom", fair: "Regular", poor: "Ruim"}
- [X] T032 [US3] Implement bitrate presets in `apps/retro_hex_chat_web/assets/js/lib/media.js`: BITRATE_PRESETS constant with high/medium/low values. applyBitratePreset(pc, preset) iterating pc.getSenders(), getting parameters via getParameters(), setting maxBitrate on encodings, calling setParameters()
- [X] T033 [US3] Wire quality polling in `apps/retro_hex_chat_web/assets/js/hooks/media_hook.js`: after call starts, set up 3-second interval calling getQualitySnapshot + mapQualityLevel, pushEvent media_quality_update with level and label. Handle media_set_preset to call applyBitratePreset. Clear interval on call end
- [X] T034 [US3] Add quality indicator and preset selector to UI in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/p2p_lobby.ex`: .media-call__quality with 4-bar indicator (filled bars based on level), quality label text. Preset selector with 3 buttons (Alta/Media/Baixa) that pushEvent media_select_preset
- [X] T035 [US3] Add quality LiveView handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_session_live.ex`: handle_event media_quality_update updates call.quality_level and call.quality_label assigns. handle_event media_select_preset pushes media_set_preset to hook
- [X] T036 [US3] Style quality indicator in `apps/retro_hex_chat_web/assets/css/media-call.css`: .media-call__quality-bars with 4 bars using CSS, colored by level (green for excellent/good, yellow for fair, red for poor). .media-call__preset-selector with 3 inline buttons

**Checkpoint**: Quality monitoring works — indicator shows 4 levels, manual preset adjusts bitrate

---

## Phase 6: User Story 4 — Audio-to-Video Upgrade (Priority: P4)

**Goal**: During audio call, either peer can request video upgrade; requires peer consent; renegotiation adds video track

**Independent Test**: Start audio call, request video upgrade, peer accepts, verify video appears. Repeat with rejection

### Tests for User Story 4

- [X] T037 [P] [US4] Write media_hook.js tests for upgrade flow in `apps/retro_hex_chat_web/assets/test/hooks/media_hook.test.js`: test "Adicionar Video" button pushes media_request_upgrade, test media_upgrade_accepted acquires video and adds track, test media_upgrade_rejected shows notification, test camera permission denied during upgrade keeps audio-only

### Implementation for User Story 4

- [X] T038 [US4] Implement upgrade request in `apps/retro_hex_chat_web/assets/js/hooks/media_hook.js`: wire "Adicionar Video" button to pushEvent media_request_upgrade. On media_upgrade_accepted, call acquireMedia for video only, add video track to PC (triggers onnegotiationneeded in WebRTCHook), attach local video to #local-video, transition UI to video layout. On media_upgrade_rejected, show notification
- [X] T039 [US4] Implement upgrade LiveView handlers in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_session_live.ex`: handle_event media_request_upgrade broadcasts {:media_upgrade_request} to peer. handle_info {:media_upgrade_request} sets call.upgrade_pending and shows consent UI. handle_event media_respond_upgrade broadcasts {:media_upgrade_response, accepted} and pushes media_upgrade_accepted/rejected to requester's hook. Update call.type from "audio" to "video" on upgrade success
- [X] T040 [US4] Add upgrade UI to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/p2p_lobby.ex`: "Adicionar Video" button visible only during audio calls. Upgrade consent banner for receiving peer with Accept/Reject buttons. Upgrade pending indicator for requester

**Checkpoint**: Audio→video upgrade works — request, consent, renegotiation, layout transition

---

## Phase 7: User Story 5 — Device Selection (Priority: P5)

**Goal**: Users can select audio/video devices during call, auto-fallback on device disconnect

**Independent Test**: During call, change microphone, verify audio switches. Simulate disconnect, verify fallback

### Tests for User Story 5

- [X] T041 [P] [US5] Write media.test.js tests for device functions in `apps/retro_hex_chat_web/assets/test/lib/media.test.js`: test enumerateDevices groups by kind, test switchAudioInput calls replaceTrack, test switchVideoInput calls replaceTrack, test supportsSetSinkId, test setSinkId

### Implementation for User Story 5

- [X] T042 [US5] Implement device management in `apps/retro_hex_chat_web/assets/js/lib/media.js`: enumerateDevices() grouping by audioinput/audiooutput/videoinput. switchAudioInput(stream, senders, deviceId) acquiring new audio track and using replaceTrack. switchVideoInput(stream, senders, deviceId) same for video. setSinkId(audioElement, deviceId) with feature detection. supportsSetSinkId() checking HTMLMediaElement.prototype
- [X] T043 [US5] Wire device selection in `apps/retro_hex_chat_web/assets/js/hooks/media_hook.js`: on device settings open, call enumerateDevices and populate selectors. On device selection change, call switchAudioInput/switchVideoInput/setSinkId. Listen for navigator.mediaDevices.ondevicechange to detect disconnection, auto-fallback to default device, pushEvent media_device_fallback with notification message
- [X] T044 [US5] Add device selector UI to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/p2p_lobby.ex`: device settings button that toggles device panel. Three select dropdowns (audio input, audio output, video input). Hide audio output if setSinkId not supported. Device fallback notification area
- [X] T045 [US5] Add device LiveView handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_session_live.ex`: handle_event media_device_fallback shows notification to user
- [X] T046 [US5] Style device selector in `apps/retro_hex_chat_web/assets/css/media-call.css`: .media-call__devices panel with retro design system select elements, .media-call__device-label, .media-call__device-fallback notification style

**Checkpoint**: Device selection works — can switch mic/camera/speaker mid-call, auto-fallback on disconnect

---

## Phase 8: User Story 6 — Browser Picture-in-Picture (Priority: P6)

**Goal**: PiP button for remote video, floating window persists across tabs, hidden if unsupported

**Independent Test**: Click PiP button, verify remote video enters PiP. Switch tabs, verify visible. Exit PiP

### Tests for User Story 6

- [X] T047 [P] [US6] Write media.test.js tests for PiP in `apps/retro_hex_chat_web/assets/test/lib/media.test.js`: test supportsPiP returns boolean based on document.pictureInPictureEnabled, test togglePiP calls requestPictureInPicture/exitPictureInPicture

### Implementation for User Story 6

- [X] T048 [US6] Implement PiP functions in `apps/retro_hex_chat_web/assets/js/lib/media.js`: supportsPiP() checking document.pictureInPictureEnabled. togglePiP(videoElement) calling requestPictureInPicture() or document.exitPictureInPicture()
- [X] T049 [US6] Wire PiP in `apps/retro_hex_chat_web/assets/js/hooks/media_hook.js`: wire PiP button to togglePiP(remoteVideoElement). On call end, exit PiP if active. On leavepictureinpicture event, update button state
- [X] T050 [US6] Add PiP button to video call UI in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/p2p_lobby.ex`: PiP button visible only during video calls when supportsPiP is true (passed as capability). Hide button if not supported
- [X] T051 [US6] Style PiP button in `apps/retro_hex_chat_web/assets/css/media-call.css`: .media-call__pip-btn using retro button style

**Checkpoint**: PiP works — remote video pops out, persists across tabs, exits on call end

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Codec preferences, help documentation, final validation

- [X] T052 Implement codec preferences in `apps/retro_hex_chat_web/assets/js/lib/media.js`: setCodecPreferences(pc) iterating pc.getTransceivers(), getting supported codecs via getCapabilities(), ordering H.264 before VP8 for video and Opus first for audio, calling transceiver.setCodecPreferences(). No-op if API not supported
- [X] T053 [P] Write media.test.js test for setCodecPreferences in `apps/retro_hex_chat_web/assets/test/lib/media.test.js`: test codec ordering with mock transceiver
- [X] T054 [P] Add help topics for audio/video calls to `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`: "Chamada de Audio" topic (how to start, mute, end), "Chamada de Video" topic (camera toggle, layout, PiP), "Dispositivos de Midia" topic (device selection, fallback), "Qualidade da Chamada" topic (indicator, presets). Add See Also cross-references to P2P session topic
- [X] T055 [P] Handle peer disconnect during call in `apps/retro_hex_chat_web/assets/js/hooks/media_hook.js`: listen for media_pc_closed CustomEvent, stop all tracks, clear intervals, pushEvent media_call_ended with reason "Peer desconectou". Ensure clean state reset
- [X] T056 Run full CI-equivalent validation pipeline per CLAUDE.md: mix compile --warnings-as-errors, then in parallel: mix format --check-formatted, mix credo --strict, make lint.js, make lint.css, npm test --prefix apps/retro_hex_chat_web/assets, mix test --include e2e, mix dialyzer

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Stories (Phase 3-8)**: All depend on Foundational phase completion
  - US1 (Audio): No dependencies on other stories
  - US2 (Video): Builds on US1 audio pipeline (extends, doesn't replace)
  - US3 (Quality): Requires active call from US1 or US2
  - US4 (Upgrade): Requires US1 (audio) and US2 (video layout)
  - US5 (Devices): Requires US1 (active call with tracks)
  - US6 (PiP): Requires US2 (video elements)
- **Polish (Phase 9)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: After Foundational — standalone MVP
- **US2 (P2)**: After US1 — extends audio with video
- **US3 (P3)**: After US1 — can parallel with US2
- **US4 (P4)**: After US1 + US2 — needs both audio and video
- **US5 (P5)**: After US1 — can parallel with US2/US3
- **US6 (P6)**: After US2 — needs video elements

### Within Each User Story

- Tests FIRST — ensure they fail before implementation
- Pure logic (media.js) before hook wiring (media_hook.js)
- Hook before LiveView handlers
- LiveView before HEEx components
- Components before CSS

### Parallel Opportunities

- T003, T004, T005 can all run in parallel (different files)
- T009, T010 can run in parallel (same file but independent test blocks)
- US3 and US5 can run in parallel after US1 (independent features)
- T052, T053, T054, T055 can all run in parallel (different files)

---

## Parallel Example: User Story 1

```bash
# Tests first (parallel):
Task: T014 — media_hook.js audio call tests

# Then implementation (sequential within, some parallel):
Task: T015 — audio call start in media_hook.js
Task: T016 — mute toggle in media_hook.js (depends on T015)
Task: T017 — call end in media_hook.js (depends on T015)
Task: T018 — LiveView handlers (can parallel with T015-T017 — different file)
Task: T019 — consent flow integration (depends on T018)
Task: T020 — UI components (depends on T018)
Task: T021 — CSS styles (can parallel with T020 — different file)
Task: T022 — permission errors (depends on T015)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T005)
2. Complete Phase 2: Foundational (T006-T013)
3. Complete Phase 3: User Story 1 — Audio Call (T014-T022)
4. **STOP and VALIDATE**: Test audio call independently
5. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 Audio Call → Test → Deploy (MVP!)
3. Add US2 Video Call → Test → Deploy
4. Add US3 Quality + US5 Devices (parallel) → Test → Deploy
5. Add US4 Upgrade → Test → Deploy
6. Add US6 PiP → Test → Deploy
7. Polish → Full CI validation → Done

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- All media data flows P2P only — zero bytes through server
- Local video MUST have `muted` attribute to prevent audio feedback
- media.js MUST NOT contain DOM manipulation or LiveView code
- media_hook.js MUST NOT contain media logic — only wiring
- All user-facing strings in Portuguese
