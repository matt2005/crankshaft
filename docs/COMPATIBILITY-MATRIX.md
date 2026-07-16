# Core-Client Compatibility Matrix

- Last Updated: 2026-07-16
- Owners: Core maintainers + client maintainers
- Scope: `crankshaft-core` WebSocket contract and client implementations

## Purpose

Track compatibility between Core WebSocket contract enforcement settings and client behavior. This matrix is the release gate reference for phasing from permissive mode to strict client contract enforcement.

## Contract Baseline

- Envelope support includes: `subscribe`, `unsubscribe`, `publish`, `service_command`, `admin_api`, `client_hello`.
- `client_hello` payload fields:
  - `client_kind`
  - `client_version`
  - `client_protocol_version`
  - `capabilities` (includes `android_auto` when required)

## Core Enforcement Modes

- Permissive mode:
  - `core.websocket.client_contract.require_hello=false`
  - Core accepts legacy clients and hello-capable clients.
- Strict mode:
  - `core.websocket.client_contract.require_hello=true`
  - Core rejects subscribe/publish/service commands before successful hello.

## Compatibility Matrix

| Core Version | Core Contract Settings | Client | Client Version Range | Expected Result | Notes |
| --- | --- | --- | --- | --- | --- |
| `main` (pre-hello enforcement) | `require_hello=false` | ui-slim | legacy (no hello) | Compatible | Legacy behavior.
| `develop` (hello-capable core) | `require_hello=false` | ui-slim | hello-capable | Compatible | Preferred migration state.
| `develop` (hello-capable core) | `require_hello=false` | ui-slim | legacy (no hello) | Compatible | Transitional support.
| `develop` (hello-capable core) | `require_hello=true` | ui-slim | hello-capable + protocol/capability compliant | Compatible | Target strict state.
| `develop` (hello-capable core) | `require_hello=true` | ui-slim | legacy (no hello) | Incompatible (expected rejection) | Must upgrade client first.

## Deprecation Tracker

| Contract Item | Current State | Owner | Target Removal/Enforcement Milestone | Evidence Required |
| --- | --- | --- | --- | --- |
| Legacy no-hello operation | Deprecated path (transitional) | Core team | Enable strict mode after all active clients pass compatibility checks | Runtime evidence + CI contract tests |
| Protocol versions below required minimum | Soft-rejected in permissive mode, hard-rejected in strict mode | Core team | Raise required protocol only after matrix green for all active clients | Matrix update + client rollout note |

## Rollout Checklist

1. Verify client hello emission and acceptance in runtime logs.
2. Validate protocol and capability checks through unit/integration tests.
3. Update this matrix with current client versions in use.
4. Enable strict mode in controlled rollout.
5. Monitor rejection/error telemetry and rollback if needed.

## Change Control

- Any core/client contract change must update this file in the same PR or companion PR.
- Any strictness change (`require_hello`, required protocol, required capability) must update:
  - expected compatible client versions,
  - deprecation tracker entries,
  - rollout evidence references.
