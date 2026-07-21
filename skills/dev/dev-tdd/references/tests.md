# Good and Bad Tests

## Good Tests

**Integration-style**: test through real interfaces, not mocks of internal parts.

```typescript
// GOOD: Tests observable behavior
test("user can checkout with valid cart", async () => {
  const cart = createCart();
  cart.add(product);
  const result = await checkout(cart, paymentMethod);
  expect(result.status).toBe("confirmed");
});
```

Characteristics:

- Tests behavior users/callers care about
- Uses public API only
- Survives internal refactors
- Describes WHAT, not HOW
- One logical assertion per test

## Bad Tests

**Implementation-detail tests**: coupled to internal structure.

```typescript
// BAD: Tests implementation details
test("checkout calls paymentService.process", async () => {
  const mockPayment = jest.mock(paymentService);
  await checkout(cart, payment);
  expect(mockPayment.process).toHaveBeenCalledWith(cart.total);
});
```

Red flags:

- Mocking internal collaborators
- Testing private methods
- Asserting on call counts/order
- Test breaks when refactoring without behavior change
- Test name describes HOW not WHAT
- Verifying through external means instead of interface

```typescript
// BAD: Bypasses interface to verify
test("createUser saves to database", async () => {
  await createUser({ name: "Alice" });
  const row = await db.query("SELECT * FROM users WHERE name = ?", ["Alice"]);
  expect(row).toBeDefined();
});

// GOOD: Verifies through interface
test("createUser makes user retrievable", async () => {
  const user = await createUser({ name: "Alice" });
  const retrieved = await getUser(user.id);
  expect(retrieved.name).toBe("Alice");
});
```

**Tautological tests**: expected value restates the implementation, so the test passes by construction.

```typescript
// BAD: Expected value is recomputed the way the code computes it
test("calculateTotal sums line items", () => {
  const items = [{ price: 10 }, { price: 5 }];
  const expected = items.reduce((sum, i) => sum + i.price, 0);
  expect(calculateTotal(items)).toBe(expected);
});

// GOOD: Expected value is an independent, known literal
test("calculateTotal sums line items", () => {
  expect(calculateTotal([{ price: 10 }, { price: 5 }])).toBe(15);
});
```

## Go

**Good — through the public interface, table-driven, error path included:**

```go
func TestCheckout(t *testing.T) {
	cases := []struct {
		name    string
		cart    Cart
		want    string
	}{
		{"valid cart confirms", Cart{Items: []Item{{Price: 10}}}, "confirmed"},
		{"empty cart rejects", Cart{}, "rejected"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			result := Checkout(tc.cart, testPaymentMethod)
			if result.Status != tc.want {
				t.Errorf("got %q, want %q", result.Status, tc.want)
			}
		})
	}
}
```

**Bad — coupled to an internal collaborator via an interface mock:**

```go
// BAD: asserts the internal call happened, not the resulting behavior
func TestCheckout_CallsPaymentProcess(t *testing.T) {
	mockPayment := &MockPaymentService{}
	Checkout(cart, mockPayment)
	if !mockPayment.ProcessCalled {
		t.Error("expected Process to be called")
	}
}
```

## Rust

**Good — through the public API:**

```rust
#[test]
fn user_can_checkout_with_valid_cart() {
    let mut cart = Cart::new();
    cart.add(product());
    let result = checkout(&cart, &test_payment_method());
    assert_eq!(result.status, OrderStatus::Confirmed);
}
```

**Bad — reaches into a private field to verify, instead of using the public result:**

```rust
// BAD: inspects internal state instead of the interface's return value
#[test]
fn checkout_sets_internal_flag() {
    let mut cart = Cart::new();
    checkout(&mut cart, &test_payment_method());
    assert!(cart.__internal_processed); // private field, implementation detail
}
```

## Python

**Good — through the public interface, parametrized:**

```python
@pytest.mark.parametrize(
    "cart, expected_status",
    [
        pytest.param(cart_with(product), "confirmed", id="valid-cart-confirms"),
        pytest.param(create_cart(), "rejected", id="empty-cart-rejects"),
    ],
)
def test_checkout(cart, expected_status):
    result = checkout(cart, payment_method)
    assert result.status == expected_status
```

Each case still runs and reports as its own test (`test_checkout[valid-cart-confirms]`), so a failure names the exact case — parametrize replaces copy-pasted near-duplicate functions, it doesn't collapse them into one undifferentiated assertion.

**Bad — patches an internal collaborator and asserts on the call:**

```python
# BAD: verifies an internal call was made, not the resulting behavior
def test_checkout_calls_payment_process(mocker):
    mock_process = mocker.patch("app.checkout.payment_service.process")
    checkout(cart, payment_method)
    mock_process.assert_called_once_with(cart.total)
```

```python
# GOOD: verifies through the interface instead
def test_checkout_charges_the_cart_total():
    result = checkout(cart, payment_method)
    assert result.amount_charged == cart.total
```
