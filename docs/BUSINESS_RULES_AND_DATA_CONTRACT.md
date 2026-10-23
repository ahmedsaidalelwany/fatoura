# Business Rules and Data Contract — Supermarket Rashed

Status: Phase 2 draft for review. This document defines target behavior before SQL schema implementation. It does not claim that database migrations or application changes have been applied or tested.

## 1. Scope and hard constraints

- Business: Supermarket Rashed, one shop and one branch, one shared inventory.
- Clients: Android and Windows. Start with five cashier devices; register/device count remains configurable.
- Backend: Supabase PostgreSQL on the Free tier only. Do not enable billing or depend on paid features.
- Connectivity: a sale is not accepted unless the server confirms the transaction. No offline sale issuance. An explicitly unissued local draft may be retained, but it must never be displayed or printed as an accepted invoice.
- PostgreSQL is the sole authority for accepted sales, purchases, stock, payments, balances and reports.
- Never ship a service-role or secret key in the Flutter client. All exposed application tables require RLS and least-privilege grants.
- Preserve existing valid behavior, but do not preserve floating-point or non-atomic behavior as an authority for money or inventory.

## 2. Product and unit rules

1. Each stock-tracked product has one base stock unit (e.g. piece, bag, bottle, kg) and a defined precision.
2. If a product is purchased by carton but sold by piece, an explicit conversion is required (e.g. 1 carton = 24 pieces). Quantities are normalized to the base unit before stock changes. No implicit conversion from product names or free text.
3. Barcode and SKU are text, not numbers, to preserve leading zeros. Enforce uniqueness within the shop when a non-empty value is present.
4. Service/non-stock lines never affect inventory. A purchase expense line without a product reference does not add stock.
5. Archived products cannot be added to new issued sales or received purchases, except through a specifically authorized historical correction process.
6. Stock-tracked products must reference a valid product and valid unit conversion in every inventory-affecting document line.
7. Fractional quantities are allowed only to the precision configured for the product's base unit; reject values beyond precision instead of silently rounding quantities.

## 3. Inventory source of truth

- Every stock-changing event creates an append-only inventory movement linked to its source document and line where applicable.
- Movement types include opening balance, purchase receipt, sale, customer return restock, supplier return, damage/write-off, stock count adjustment, and documented cancellation/reversal.
- A current stock balance may be stored for efficient reads, but it must be updated in the same PostgreSQL transaction as the movement and be reconcilable against the movement ledger.
- Users must not directly edit the authoritative stock quantity field. Stock corrections are explicit, permission-controlled adjustment documents with reason, actor and timestamp.
- No negative available stock. PostgreSQL validates and changes stock atomically, not based on a stale quantity displayed in Flutter.
- For each tracked product, expected stock is opening balance plus all posted inbound movements minus all posted outbound movements. A reconciliation report must identify any difference between this ledger total and the current balance.

## 4. Purchase and supplier rules

1. A draft purchase has no inventory or supplier-balance effect.
2. Receiving/posting a purchase validates all lines and commits purchase status, line snapshots, inventory movements, stock balances, supplier payable and idempotency result in one transaction.
3. Receiving a stock-tracked product increases stock exactly once. Repeating the same request with the same idempotency key returns the previous result without duplicate movement or payable.
4. Each received line snapshots product name, unit, conversion, quantity, unit cost, discount allocation, tax/fees if applicable, and currency. Later edits to the product master must not rewrite historical purchase values.
5. Supplier payment is independent from receipt. Receiving goods on credit increases stock and supplier payable but does not mark the invoice paid.
6. Payment allocations cannot exceed the outstanding payable unless a separately modeled supplier credit/advance is intentionally supported.
7. A received purchase is immutable in its stock-affecting terms. Corrections use audited supplier returns, credit/debit adjustments, or reversal documents.
8. A full purchase cancellation/reversal is allowed only when policy checks prove it will not create inconsistent downstream stock; if received goods have already been sold or consumed, block a naive reversal and require a documented compensating process.
9. A purchase line without a product ID is treated as a non-stock expense/charge only if the document model explicitly supports that line type; it never silently increases inventory.

## 5. Sales and cashier rules

1. Draft sales do not affect stock, revenue, receivables or cash.
2. Issuing a sale validates session and permissions, product availability, quantities, price/discount/tax snapshots, payment data and idempotency key on the server.
3. Invoice header, lines, stock decrements, inventory movements, payment/receivable effects, audit data and idempotency result commit atomically.
4. If any line or validation fails, the entire transaction rolls back; no partial invoice and no partial stock decrement.
5. The same idempotency key with the same authenticated cashier/device and equivalent payload returns the original result. Reuse with a different payload is rejected.
6. No sale may exceed available stock. Two cashiers attempting to sell the last unit concurrently must result in at most one accepted sale.
7. Prices, discounts, taxes and product descriptions used on an issued invoice are immutable snapshots. Corrections use a return, cancellation or adjustment workflow rather than editing issued financial facts.
8. The server's confirmed result is the only condition under which UI/receipt can say the sale is accepted. A timeout with unknown outcome must be resolved by querying/retrying with the same idempotency key, never by generating a new key blindly.
9. A sale request without connectivity is not issued. Any local draft must be visibly marked pending/unissued and must not reserve stock or be included in official reports.

## 6. Customer returns, supplier returns, damage and adjustments

- Customer return quantity for a line must not exceed the original issued quantity minus prior accepted returns for that line.
- A return records the original invoice and line, returned quantity, refund/credit amount, reason, actor, timestamp and disposition.
- Returned goods increase saleable stock only if marked inspected/resalable. Damaged/non-resalable goods go to a non-saleable disposition and do not increase available stock.
- Refund/payment effects are recorded separately from physical stock disposition; a stock return is not automatically proof that cash was refunded.
- Supplier returns reduce available stock and supplier payable/credit according to the source purchase and actual settlement terms. Never silently delete the original receipt movement.
- Damage, expiry, loss and stock-count differences use explicit adjustment documents with reason and approval permissions. They create movements and audit entries.
- A document already linked to accepted returns/payments cannot be silently deleted or reset. Use compensating records and preserve history.

## 7. Inventory cost and profit rules

- Recommended valuation method: perpetual weighted-average cost for stock-tracked products, calculated on the server using exact decimal arithmetic.
- On purchase receipt, new average cost = (old on-hand quantity × old average cost + received base quantity × landed unit cost) / (old on-hand quantity + received base quantity). If on-hand quantity is zero, the received cost becomes the new average cost.
- Discounts and eligible inbound costs must be allocated consistently to received lines before average cost is calculated. Non-inventory expenses must not be capitalized accidentally.
- A sale snapshots the applicable average cost at issue time for cost-of-goods-sold reporting. Later purchases must not rewrite the cost snapshot of historical sales.
- Returns and reversals must restore or reverse the original cost effects according to the same valuation policy; do not recalculate historical sale cost from today's average.
- Use PostgreSQL NUMERIC for authoritative quantities and amounts with documented scale/precision, and Dart Decimal or integer minor units at the app boundary. Do not use binary floating point for authoritative money calculations.
- Store currency code with every financial document and payment. Never add amounts across different currencies without an explicit conversion record and rate. Preserve supported currency behavior from the current application unless the product owner approves narrowing it.
- Rounding policy, currency minor units, discount allocation, tax treatment and landed-cost eligibility must be specified and tested before implementing the costing function.

## 8. Payments, debts, cash and shifts

- Stock movement, invoice amount, payment, supplier/customer balance and cash movement are related but distinct facts.
- Each payment has a method, currency, amount, timestamp, actor, reference and explicit allocations to invoices or supplier documents.
- Partial payments reduce outstanding balance by the amount allocated; they do not change stock.
- A payment reversal/refund is a new audited financial record, not deletion of the original payment.
- Cashier shifts and cash drawers record opening float, cash in/out, payments/refunds and closing reconciliation. Cash totals must not be inferred only from sales totals.
- Unallocated customer/supplier credits, advances and overpayments require explicit models and must not be hidden as negative invoice balances.

## 9. Target data entities (logical model)

- shops: one record for Supermarket Rashed; ownership boundary remains explicit.
- branches: one active branch initially; future-safe structure without requiring multi-branch operation in v1.
- profiles: authenticated user profile and active status; authorization role is server-controlled, not taken from user-editable metadata.
- shop_memberships / role assignments: user-to-shop scope and role (owner/admin, manager, cashier, stock clerk as needed).
- registers and devices: configurable cashier/register records, active/revoked status, device identity and assignment.
- products, product_units / unit_conversions, product_barcodes, categories.
- suppliers, customers.
- purchase_documents, purchase_lines, supplier_returns, supplier_return_lines.
- sales_documents, sales_lines, customer_returns, customer_return_lines.
- inventory_movements and optionally inventory_balances as a transactionally maintained projection.
- payments, payment_allocations, cash_movements, cashier_shifts.
- stock_adjustments and stock_adjustment_lines.
- idempotency_requests for replay-safe mutation outcomes.
- audit_events for sensitive changes, reversals, permission changes and document corrections.
- backup/export metadata only if operationally needed; actual backups must also be exported outside the Supabase project.

These are logical names, not final SQL identifiers. Final table design must avoid redundant columns and preserve referential integrity.

## 10. Document lifecycle and audit

- Use explicit draft/posted/partially-returned/returned/cancelled states as appropriate; do not overload payment status as document status.
- Draft documents can be edited or deleted under permission rules. Posted documents are immutable in stock/financial facts and are corrected through auditable compensating records.
- Each posted document stores created/posted timestamps, actor, register/device, currency, totals and immutable line snapshots.
- Every privileged action records actor, timestamp, action, entity, entity ID, reason, and safe before/after differences without secrets.
- Server time is authoritative for posting timestamps. Client time may be retained as diagnostic metadata but cannot establish posting order.

## 11. Transaction and security requirements

- Implement high-risk operations as PostgreSQL functions/RPCs with explicit validation and one transaction: receive purchase, issue sale, accept customer return, accept supplier return, record payment, post adjustment, and reverse eligible documents.
- Protect concurrency with row-level locking or conditional atomic updates and constraints; never trust a stock value sent by the client.
- Give functions only required privileges and review EXECUTE grants. Avoid SECURITY DEFINER unless specifically justified, isolated in a non-exposed schema, and guarded by explicit authorization checks.
- Enable RLS on all exposed tables. Scope policies to shop membership and role, not merely to the fact a user is authenticated.
- Never expose service-role/secret keys in Flutter. Store role assignments in protected server-controlled data, not user-editable user_metadata.
- Use server-side validation for prices, discounts, payment allocations and inventory quantities; client validation is UX only.

## 12. Required acceptance tests before schema approval

1. Stock 100 + receipt 100 = 200, with one and only one purchase receipt movement.
2. Retry receipt with same idempotency key = no duplicate stock, payable or movement.
3. Stock 200 - sale 15 = 185 and invoice/movements/payments all agree.
4. Reject sale quantity above stock and leave every table unchanged.
5. Two cashiers concurrently sell the last unit: one succeeds at most.
6. Failure on any sale/purchase line rolls back the entire operation.
7. Customer return is limited to original quantity minus prior returns.
8. Resalable return increases available stock; damaged return does not.
9. Supplier return reduces stock and supplier balance correctly without deleting original receipt.
10. Supplier invoice on credit increases payable but does not create a cash payment.
11. A received purchase cannot be edited in a way that silently changes stock/cost history.
12. Historical sale COGS remains stable after a later purchase changes average cost.
13. Unit conversion (e.g. 2 cartons × 24 pieces) updates stock by 48 base units.
14. Barcode leading zeros survive round-trip.
15. Cross-shop/unauthorized access fails even for an authenticated user.
16. Offline sale cannot appear as accepted; retry after timeout with same key cannot duplicate.
17. Stock ledger reconciliation equals stored balance for every product.
18. Export and restore reproduce document counts, movements and balances.

## 13. Decisions to finalize during schema review

- Exact product base-unit precision and supported unit conversions.
- Whether tax is used and whether prices are tax-inclusive.
- Exact discount allocation and landed-cost policy.
- Payment methods and cash-shift requirements for v1.
- Whether non-resalable returns use a separate quarantine/damaged stock bucket or a disposition ledger only.
- How current Hive data will be exported, mapped, imported and reconciled.

Do not create production migrations or remove Hive until these rules and the migration base branch have been reviewed. This phase creates the contract only; it does not claim that database operations or tests have run.
