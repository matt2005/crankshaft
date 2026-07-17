- source_spec: `{implementation_artifacts}/spec-flicker-webrtc-display-recovery.md`
  summary: Add core WebRTC degradation policy and explicit health fields in channel-status payload for cross-client consumption.
  evidence: This is independently shippable backend hardening and schema work beyond the immediate UI-Slim blank projection recovery goal.
- source_spec: `{implementation_artifacts}/spec-flicker-webrtc-display-recovery.md`
  summary: Add dedicated crankshaft-core unit tests for WebRTC push-failure degradation and health publication semantics.
  evidence: Core test expansion can ship separately after UI fallback behavior is stabilized and verified on-device.
- source_spec: `{implementation_artifacts}/spec-ui-slim-core-connection-grace-window.md`
  summary: Bound transient projection-state hold duration across repeated CoreClient socket flaps to prevent indefinite stale readiness.
  evidence: Review identified a pre-existing reconnect flapping risk in CoreClient transient hold behavior outside this story's state-machine scope.
- source_spec: `{implementation_artifacts}/spec-ui-slim-core-connection-grace-window.md`
  summary: Add CoreClient contract tests for reconnect-hold edge timing and guaranteed teardown signaling semantics.
  evidence: Findings surfaced test gaps in pre-existing CoreClient disconnect/hold paths not introduced by this UI-slim connection-state-machine change.
