
# Tawseel Flutter Project Rules

## Environment
- Use Flutter 3.47.6 and Dart 3.13.
- Use the existing http 1.6.0 dependency.
- Keep the package name dsc26_flt_w04 unchanged.
- Use the existing FVM configuration.

## Project Structure
- Keep delivery models in lib/domain/.
- Keep local storage and Outbox logic in lib/data/.
- Keep presentation code in lib/ui/stops/.
- Do not modify lib/domain/delivery_outcome.dart or lib/domain/stop.dart.
- Preserve the existing LocalStore interfaces.
- Do not add unnecessary dependencies or state-management packages.

## Outbox
- Implement Outbox and retryDelay in lib/data/outbox.dart.
- Store the queue using the key tawseel.outbox.v1.
- Persist the complete queue before confirming a record operation.
- Preserve FIFO ordering when sending pending outcomes.
- Send requests to POST {baseUrl}/v1/outcomes.
- Include Content-Type and Idempotency-Key headers.
- Treat HTTP 200, 201, and 409 as successful responses.
- Mark HTTP 400 and 422 responses as rejected.
- Stop synchronization on HTTP 401.
- Stop on transient failures without skipping the current entry.
- Prevent concurrent sync calls using single-flight behavior.
- Apply exponential retry delays: 5, 10, 20, 40, 80, 160, then 300 seconds.
- Replace only pending corrections with zero attempts.

## UI and Accessibility
- Keep stop-list UI components in lib/ui/stops/.
- Use a 600 logical pixel breakpoint for expanded layouts.
- Support both LTR and RTL layouts.
- Support text scaling up to 200% without overflow.
- Ensure tappable controls are at least 48x48 logical pixels.
- Give interactive controls accessible labels.
- Keep the sync banner's required semantics label and live region.
- Use directional positioning instead of left/right positioning.

## Verification
- Run flutter pub get after dependency changes.
- Run flutter test to verify the implementation.
- Run flutter analyze to check static issues.
- Test FIFO, persistence, retry, and concurrent synchronization.
- Test layouts at 360, 599, 600, 800, and 1024 logical pixels.
- Use synthetic test data and never depend on live network access.

## Before Completing
- Inspect relevant files before editing.
- Preserve existing constructors and required widget keys.
- Keep changes limited to the requested task.
- Report actual test results.
