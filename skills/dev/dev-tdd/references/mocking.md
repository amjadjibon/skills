# When to Mock

Mock at **system boundaries** only:

- External APIs (payment, email, etc.)
- Databases (sometimes — prefer a test DB)
- Time/randomness
- File system (sometimes)

Don't mock:

- Your own classes/modules
- Internal collaborators
- Anything you control

## Designing for Mockability

At system boundaries, design interfaces that are easy to mock.

**1. Use dependency injection** — pass external dependencies in rather than creating them internally:

```typescript
// Easy to mock
function processPayment(order, paymentClient) {
  return paymentClient.charge(order.total);
}

// Hard to mock
function processPayment(order) {
  const client = new StripeClient(process.env.STRIPE_KEY);
  return client.charge(order.total);
}
```

**2. Prefer SDK-style interfaces over generic fetchers** — create specific functions for each external operation instead of one generic function with conditional logic:

```typescript
// GOOD: Each function is independently mockable
const api = {
  getUser: (id) => fetch(`/users/${id}`),
  getOrders: (userId) => fetch(`/users/${userId}/orders`),
  createOrder: (data) => fetch('/orders', { method: 'POST', body: data }),
};

// BAD: Mocking requires conditional logic inside the mock
const api = {
  fetch: (endpoint, options) => fetch(endpoint, options),
};
```

The SDK approach means:

- Each mock returns one specific shape
- No conditional logic in test setup
- Easier to see which endpoints a test exercises
- Type safety per endpoint

## Go

**Mocking boundary:** Go's implicit interfaces make this natural — define a small interface at the boundary (`PaymentClient` with just `Charge(amount int) error`), inject it, and mock only that interface in tests. Don't mock a concrete struct from your own package; if you're tempted to, the seam is probably in the wrong place.

**Testing quality:**

- **Cover the error path, not just the happy one.** A table case with `wantErr: true` and an assertion on the returned `error` (or `errors.Is`/`errors.As` for a specific sentinel/type) belongs next to the success cases in the same table — a function that returns `(T, error)` isn't fully tested until something has forced the error branch.
- **`t.Parallel()` once subtests don't share mutable state.** Table-driven subtests are usually independent by construction — mark them parallel to keep the suite fast as it grows, but only after confirming there's no shared fixture or global being mutated.
- **`go test -fuzz` for parsers, serializers, or anything taking arbitrary input** — example-based table tests catch the cases you thought of; fuzzing finds the ones you didn't, and is stdlib-native since Go 1.18, no new dependency needed.
- **`t.Helper()` in shared test-setup functions** so a failure reports the call site in the actual test, not a line inside the helper — otherwise every failure sends you to the wrong place first.

## Rust

**Mocking boundary:** define a trait at the system boundary (`trait PaymentGateway { fn charge(&self, cents: u64) -> Result<(), PaymentError>; }`), inject `impl PaymentGateway` (or `Box<dyn PaymentGateway>`), and provide a test double only for that trait. Don't add a trait purely to make an internal, same-crate function mockable — that's implementation-coupling with extra steps.

**Testing quality:**

- **Match on the `Err` variant, don't just check `is_err()`.** `assert!(matches!(result, Err(PaymentError::InsufficientFunds)))` tells you the *right* error occurred; `assert!(result.is_err())` passes just as well when the code fails for the wrong reason.
- **`proptest` or `quickcheck` for pure functions with a large input space** — an invariant like "parsing then serializing returns the original value" or "total is never negative" holds for *all* inputs, not just the two or three examples you thought to write by hand. Property tests complement the example-based tests; they don't replace the specific, readable "checkout confirms" case.
- **`cargo test` runs tests in parallel by default** — a test relying on shared mutable state (a fixed temp file path, a global counter) will flake under that parallelism. Give each test its own isolated fixture (a tempdir via `tempfile`, a fresh in-memory instance) rather than reaching for `--test-threads=1` to paper over shared state.
- **`#[should_panic(expected = "...")]` for a genuine panic-on-invalid-input contract** — but only when panicking is the documented behavior; if the function should return `Result::Err` instead, test that, don't make it panic just to have something to assert on.

## Python

**Mocking boundary:** `unittest.mock.patch` (or `pytest-mock`'s `mocker`) should target the boundary your code calls out through — the Stripe/requests/email client — not a sibling function or class in your own codebase. If a test needs `mocker.patch("myapp.internal_module.some_function")`, that's a sign the test is reaching across an internal seam rather than testing through the public one.

**Testing quality:**

- **`pytest.raises` for the exception path**, asserting on the exception type (and message when it carries information the caller acts on) — `with pytest.raises(InsufficientFundsError): checkout(empty_wallet_cart, payment_method)`, not just testing the success return value and hoping errors are someone else's problem.
- **`hypothesis` for pure functions with a large or awkward input space** (parsing, numeric edge cases, anything with off-by-one risk) — it generates and shrinks failing cases automatically, finding the edge case a hand-written example would've missed, as a complement to the specific example-based tests, not a replacement.
- **Don't let tests depend on run order or shared fixture state.** A module-scoped fixture mutated by one test and read by another passes only by accident of execution order — scope fixtures (`function` scope by default) to match what actually needs to be isolated per test.
