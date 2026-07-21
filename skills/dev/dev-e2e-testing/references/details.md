# E2E Testing Templates

Worked examples for `dev-e2e-testing`. Adapt names/selectors, don't paste unmodified.

## 1. Playwright — Config

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  retries: process.env.CI ? 1 : 0,   // CI: one retry for infra hiccups, not to mask real flake
  workers: process.env.CI ? 4 : undefined,
  reporter: [['html', { open: 'never' }], ['github']],
  use: {
    baseURL: process.env.E2E_BASE_URL ?? 'http://localhost:3000',
    trace: 'on-first-retry',   // captures a debuggable trace only when something went wrong
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
});
```

## 2. Playwright — Test with Independent Fixture Data

```typescript
import { test, expect } from '@playwright/test';
import { createTestUser, createTestOrder } from './support/fixtures';

test('user can checkout with a saved card', async ({ page }) => {
  const user = await createTestUser();          // uniquely-namespaced, not shared
  const order = await createTestOrder(user.id);

  await page.goto(`/orders/${order.id}/checkout`);
  await page.getByRole('button', { name: 'Pay with saved card' }).click();

  await expect(page.getByText('Order confirmed')).toBeVisible();
});
```

`createTestUser`/`createTestOrder` seed real data through the app's own API (a test-account signup endpoint, a seed script) — never insert rows directly into the DB, that bypasses the same validation/side-effects a real user would trigger and can silently drift from reality.

## 3. Page Object Pattern (Keep Selectors DRY)

```typescript
// tests/e2e/support/pages/checkout-page.ts
export class CheckoutPage {
  constructor(private page: Page) {}

  async payWithSavedCard() {
    await this.page.getByRole('button', { name: 'Pay with saved card' }).click();
  }

  async expectConfirmed() {
    await expect(this.page.getByText('Order confirmed')).toBeVisible();
  }
}
```

A selector changing (button text, layout) means editing one page object, not every test that clicks that button — worth it once more than 2-3 tests touch the same screen; overkill for a one-off test.

## 4. CI Sharding

```yaml
strategy:
  matrix:
    shard: [1, 2, 3, 4]
steps:
  - run: npx playwright test --shard=${{ matrix.shard }}/4
```

Split the suite across workers once it's slow enough to matter — sharding a 30-second suite into 4 jobs adds more CI queue/startup overhead than it saves.

## 5. Flake Troubleshooting Checklist

- Does the failure reproduce locally, headed, on a slow network throttle? If only in CI, suspect resource contention (too many parallel workers for the runner's CPU), not the test logic.
- Is there a `sleep`/fixed `wait(ms)` anywhere in the failing path? Replace with an explicit wait for the actual condition.
- Does the test depend on data from another test or a fixed ID that could collide under parallel execution? Namespace the fixture data uniquely per test run.
- Is the assertion checking a transient loading state instead of the final settled state? Wait for the loading indicator to disappear before asserting on content.
