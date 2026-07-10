# Embedded Group-Call SFU

Operational notes for the application-side SFU runtime. Network/firewall port
opening is handled outside this repository.

## Runtime Env

| Env | Default | Purpose |
|---|---:|---|
| `GROUP_CALL_ENABLED` | `true` | Enables channel group calls. |
| `GROUP_CALL_MAX_PARTICIPANTS` | `100` | Per-room participant cap enforced by the app. |
| `GROUP_CALL_READY_TIMEOUT_MS` | `10000` | Max time for a joining peer to complete media readiness. |
| `GROUP_CALL_RECONNECT_TIMEOUT_MS` | `30000` | Time a disconnected participant keeps their logical slot. |
| `GROUP_CALL_PEERLESS_TIMEOUT_MS` | `60000` | Time before an empty room is closed. |
| `GROUP_CALL_CREATE_RATE_LIMIT_COUNT` | `3` | Room creation attempts per window. |
| `GROUP_CALL_CREATE_RATE_LIMIT_WINDOW_MS` | `600000` | Room creation rate-limit window. |
| `GROUP_CALL_JOIN_RATE_LIMIT_COUNT` | `20` | Join attempts per window. |
| `GROUP_CALL_JOIN_RATE_LIMIT_WINDOW_MS` | `60000` | Join rate-limit window. |
| `GROUP_CALL_SIGNAL_RATE_LIMIT_COUNT` | `300` | SDP/ICE/media-state messages per room/user window. |
| `GROUP_CALL_SIGNAL_RATE_LIMIT_WINDOW_MS` | `60000` | Signaling rate-limit window. |
| `SFU_ICE_PORT_RANGE` | `50000-50100` | UDP port range the app asks ExWebRTC to use. |
| `SFU_ICE_TRANSPORT_POLICY` | `all` | `all` or `relay`. |
| `SFU_PUBLIC_IP` | unset | Optional public IP mapper for fabricated srflx candidates. |

## Metrics

The app emits telemetry under `[:retro_hex_chat, :group_call, ...]` and exposes
the corresponding metrics through the existing metrics pipeline:

- active room process count;
- active peer process count;
- join attempts;
- participant leaves;
- track announcements;
- media state changes;
- moderator media actions;
- participant kicks;
- room closures.

## Local Scale Inspection

Use the deterministic BEAM-side inspection helper for fanout and payload checks
before scheduling browser-load work:

```bash
rtk mix run --no-start -e 'IO.inspect(RetroHexChat.GroupCall.ScaleInspection.run([3, 10, 25, 50, 100]), limit: :infinity)'
```

This does not start browsers or RTP media. It reports:

- expected N:N fanout routes for the given participant counts;
- JSON byte size for the group-call UI event payloads;
- `PeerServer` memory, mailbox and reductions when the peer registry is running.

## Scope Boundary

This repository owns the application behavior, configuration knobs and metrics.
Opening UDP ranges, firewall rules, load balancer settings and deploy-specific
NAT/TURN validation belong to the infrastructure task/repository.
