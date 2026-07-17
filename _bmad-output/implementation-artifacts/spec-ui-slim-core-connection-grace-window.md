---
title: 'UI Slim Core Connection Grace Window'
type: 'bugfix'
created: '2026-07-17'
status: 'done'
baseline_commit: 'fe6ec9ca73bb51f98d570d62ea5428c52470f2ae'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/docs/COMPATIBILITY-MATRIX.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** UI Slim intermittently reports a lost core connection and tears down projection during short-lived connection churn, even when the core recovers quickly. This causes visible flicker and false error UX on Raspberry Pi runtime traces.

**Regression Note (current):** Since the latest UI Slim connection-state changes, UI Slim has not successfully established a stable Core connection in runtime validation. This indicates a higher-severity baseline-connectivity regression in addition to the transient-drop misclassification.

**Approach:** First restore baseline Core connection establishment reliability, then add a bounded grace window so Connected -> Disconnected transitions are treated as provisional until sustained. Keep immediate failure behavior for explicit core failure signals, and preserve eventual error reporting for real outages.

## Boundaries & Constraints

**Always:**
- Keep crankshaft-core behavior client-agnostic; implement this fix in ui-slim only.
- Prioritize restoring successful initial connection to Core before tuning transient disconnect policy.
- Use bounded, deterministic timing with a single grace timer and explicit cancellation paths.
- Preserve immediate failure handling when the facade emits explicit connection failure.
- Preserve existing reconnect flow and retry limits; do not introduce unbounded loops.
- Add regression tests for initial-connect success, transient drop, sustained drop, explicit failure, and intentional stop.

**Ask First:**
- Changing the lost-connection message text or user-facing wording.
- Changing retry policy defaults beyond a short grace delay.
- Any cross-repo protocol/contract change.

**Never:**
- Do not patch by suppressing all disconnect errors.
- Do not move connection error policy into QML.
- Do not alter websocket protocol negotiation or core transport semantics.
- Do not push directly to protected develop.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| POST_CHANGE_BASELINE_CONNECT | Fresh UI Slim start, Core reachable, transport and facade initialized after recent changes | UI Slim reaches Connected within bounded startup window and does not enter immediate Error loop | If startup window is exceeded, emit explicit diagnostic reason and fail boundedly |
| TRANSIENT_DROP_RECOVERS | State machine is Connected, facade briefly reports Disconnected then returns to Connecting/Connected within grace window | No transition to Error, no lost-core message, no spurious hard failure path | Grace timer is canceled on recovery |
| SUSTAINED_DROP | State machine is Connected, facade remains Disconnected beyond grace window | Transition to Error via existing failure path, lost-core message emitted once, retry flow proceeds | Uses existing bounded retry/error behavior |
| EXPLICIT_FAILURE_SIGNAL | Facade emits connectionFailed(reason) at any time, including during grace window | Immediate Error transition with provided reason | Bypasses grace, maintains current explicit-failure semantics |
| INTENTIONAL_STOP | User-initiated stop from Connected | Transition to Disconnected without lost-core error UX | Grace/failure path is bypassed for intentional stop |

</frozen-after-approval>

## Code Map

- `src/crankshaft-ui-slim/src/ConnectionStateMachine.h` -- add bounded grace-timer members and explicit intentional-stop tracking used by state transition handlers.
- `src/crankshaft-ui-slim/src/ConnectionStateMachine.cpp` -- fix startup-connect regression path, implement provisional Connected -> Disconnected handling in `onFacadeConnectionStateChanged`, keep `onFacadeConnectionFailed` immediate, and ensure timer cancellation on recovery/stop.
- `src/crankshaft-ui-slim/src/tests/test_connection_state_machine.cpp` -- add regression coverage for baseline startup connect, transient-drop recovery, sustained-drop escalation, explicit-failure precedence, and intentional-stop behavior.
- `src/crankshaft-ui-slim/src/AndroidAutoFacade.cpp` -- reference existing `disconnectionRequested` semantics for intentional-stop path; no contract or schema changes planned.
- `src/crankshaft-ui-slim/src/AndroidAutoFacade.h` -- reference only for existing signal/property contracts consumed by state machine tests.
- `src/crankshaft-ui-slim/src/qml/main.qml` -- reference behavior only; no UI message or transport-policy changes planned.

## Tasks & Acceptance

**Execution:**
- [x] `src/crankshaft-ui-slim/src/ConnectionStateMachine.h` -- introduce connected-drop grace constants, single-shot timer handle, and intentional-stop flag/state -- required to model provisional disconnect deterministically.
- [x] `src/crankshaft-ui-slim/src/ConnectionStateMachine.cpp` -- isolate and fix post-change startup/connect regression so reachable Core startup can transition to Connected within existing bounded timeout -- restores baseline functionality before grace tuning.
- [x] `src/crankshaft-ui-slim/src/ConnectionStateMachine.cpp` -- defer Connected -> Disconnected lost-core escalation until grace expiry; cancel grace on recovery to Connecting/Connected; bypass grace on explicit user stop -- removes false positives while preserving real-failure behavior.
- [x] `src/crankshaft-ui-slim/src/ConnectionStateMachine.cpp` -- keep `onFacadeConnectionFailed(reason)` immediate and dominant over grace state -- preserves explicit failure semantics and operator signal quality.
- [x] `src/crankshaft-ui-slim/src/ConnectionStateMachine.cpp` -- ensure stale or overlapping timers cannot trigger duplicate escalation paths -- keeps behavior bounded and deterministic under churn.
- [x] `src/crankshaft-ui-slim/src/tests/test_connection_state_machine.cpp` -- add startup baseline-connect regression test proving reachable Core can enter Connected after recent changes -- guards against recurrence of total-connectivity failure.
- [x] `src/crankshaft-ui-slim/src/tests/test_connection_state_machine.cpp` -- add edge-case tests for transient recovery, sustained drop, explicit-failure precedence, and intentional-stop bypass -- validates required semantics and prevents regressions.
- [x] `src/crankshaft-ui-slim/src/tests/test_connection_state_machine.cpp` -- assert no spurious Error state or `maxRetriesReached` emission during brief churn -- protects against projection flicker/error storms.

**Acceptance Criteria:**
- Given Core is reachable and UI Slim starts cleanly, when startup connection flow executes, then UI Slim must reach Connected at least once within bounded startup time and must not fail immediately due to the recent regression path.
- Given an active connected session, when Disconnected is brief and recovery occurs within grace, then UI Slim must not enter Error and must not emit a lost-core error.
- Given an active connected session, when Disconnected persists beyond grace, then UI Slim must enter existing Error/retry flow with the lost-core reason.
- Given any session state, when explicit facade connectionFailed(reason) is emitted, then UI Slim must fail immediately with that reason, regardless of grace state.
- Given user-initiated stop while connected, when disconnect is intentional, then UI Slim must end in Disconnected without lost-core error reporting.
- Given repeated transient churn, when reconnect attempts proceed, then behavior remains bounded with no unbounded retry/timer escalation.

## Spec Change Log

- 2026-07-17: Refined scope to include post-change baseline-connectivity regression where UI Slim fails to connect to Core at all; added startup-connect scenario, tasks, and acceptance coverage before grace-window behavior tuning.

## Design Notes

The failure mode is not protocol incompatibility; it is classification timing. A short disconnect can occur during transport churn while the system is still converging. The fix therefore belongs at the policy layer in the connection state machine, not in UI rendering and not in websocket protocol handlers.

Golden behavior:
1. Connected -> Disconnected starts a short hold.
2. Recovery before timeout cancels escalation.
3. Timeout without recovery escalates exactly once through existing error flow.
4. Explicit connectionFailed bypasses hold and fails immediately.
5. User stop bypasses escalation entirely.

## Verification

**Commands:**
- `cmake --build build --target crankshaft-ui-slim-tests` -- expected: ui-slim test target builds with new state-machine symbols.
- `ctest --output-on-failure --test-dir build -R connection_state_machine` -- expected: connection-state-machine tests pass, including new transient/sustained/explicit/intentional cases.
- `ctest --output-on-failure --test-dir build -R android_auto_facade|core_mock_integration` -- expected: related facade/integration tests remain green with no behavior regressions.
- `ctest --output-on-failure --test-dir build` -- expected: no regressions in ui-slim suite.

**Manual checks (if no CLI):**
- On RPi3 logs, trigger brief network/core churn and verify no immediate lost-core popup or projection teardown for sub-grace reconnects.
- Simulate sustained core outage and verify lost-core message and retry behavior still occur.

## Suggested Review Order

**Connection-state policy and precedence**

- Start with the drop classification entry point and grace/timer cancellation policy.
  [ConnectionStateMachine.cpp:164](../../src/crankshaft-ui-slim/src/ConnectionStateMachine.cpp#L164)

- Confirm explicit failure precedence and intentional-stop suppression semantics.
  [ConnectionStateMachine.cpp:194](../../src/crankshaft-ui-slim/src/ConnectionStateMachine.cpp#L194)

- Verify grace expiry escalation only triggers for sustained disconnected facade state.
  [ConnectionStateMachine.cpp:287](../../src/crankshaft-ui-slim/src/ConnectionStateMachine.cpp#L287)

**State model extensions**

- Review new timer/flag members that bound provisional disconnect behavior.
  [ConnectionStateMachine.h:87](../../src/crankshaft-ui-slim/src/ConnectionStateMachine.h#L87)

- Check grace-duration constant and private API additions for determinism.
  [ConnectionStateMachine.h:119](../../src/crankshaft-ui-slim/src/ConnectionStateMachine.h#L119)

**Regression tests**

- Validate baseline connect success plus transient drop non-escalation coverage.
  [test_connection_state_machine.cpp:96](../../src/crankshaft-ui-slim/src/tests/test_connection_state_machine.cpp#L96)

- Validate sustained drop escalation and retry-path assertions.
  [test_connection_state_machine.cpp:135](../../src/crankshaft-ui-slim/src/tests/test_connection_state_machine.cpp#L135)

- Validate intentional stop plus failure-signal race suppression.
  [test_connection_state_machine.cpp:155](../../src/crankshaft-ui-slim/src/tests/test_connection_state_machine.cpp#L155)
