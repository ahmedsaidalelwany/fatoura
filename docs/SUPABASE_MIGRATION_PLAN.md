# Supabase Migration Plan — Supermarket Rashed

## Goal
Migrate the current Fatoura codebase from Hive as the operational source of truth to Supabase/PostgreSQL for one shop and one branch. Five cashier devices are the initial deployment, but the number of registered devices must be configurable. Android and Windows are in scope.

## Non-negotiable operating rules
- Supabase Free only. Do not link a billing account, enable paid products, or introduce dependencies that require paid subscriptions.
- Central PostgreSQL is the sole authority for accepted sales, stock, payments, and reports.
- A cashier must not issue/commit a sale when the server cannot be reached. Local drafts may be retained only if explicitly labelled unissued and never represented as accepted.
- Sale creation, stock validation/decrement, invoice lines, and idempotency result must commit in one PostgreSQL transaction.
- Every mutating request has a client-generated idempotency UUID. A retry returns the prior result instead of creating a second invoice.
- Never ship Supabase service-role/secret keys in Flutter. Client uses the publishable/legacy anon key plus authenticated sessions and RLS.
- Every exposed application table has RLS and least-privilege grants. No authorization decisions based on user-editable user_metadata.
- Financial and inventory corrections are auditable; do not silently delete issued documents or stock movements.

## Target architecture
- Flutter UI and existing Cubit boundaries are retained where practical.
- A Supabase initialization/configuration layer is added.
- Repository interfaces remain the domain boundary; Hive implementations are replaced with Supabase implementations feature by feature.
- PostgreSQL owns concurrency-sensitive business rules. Realtime notifications, if used, are only a UI refresh mechanism and never the authority for stock.
- SharedPreferences may remain for non-sensitive device preferences only; it is not a business database.
- Hive is removed from production dependencies only after every business repository, backup/restore path, startup path, and test has been migrated and verified. No mixed-source-of-truth period is allowed.

## Migration phases
1. Baseline: preserve the current branch, inspect all repositories/entities/tests and document current behaviours.
2. Data contract: map existing models to PostgreSQL types. Use numeric for fractional quantities and exact decimal values for money, or integer minor units where compatible with existing currency rules. Never use floating-point arithmetic in authoritative database calculations.
3. Database: add versioned SQL migrations, constraints, indexes, RLS policies, role/device records, immutable inventory movements, audit records, and transaction functions for critical operations.
4. Identity and permissions: authenticated user profiles, owner/manager/cashier permissions, device/register registration, and server-side authorization.
5. Repository migration: replace product/party repositories, then purchases/payments/returns, then invoices and reporting. Keep domain interfaces stable where possible.
6. Bootstrap: replace Hive initialization and sequence manager with Supabase-backed dependencies; remove Hive only when no business code imports it.
7. Backup: implement a documented export/import format and test a full restore independently of managed Supabase backups.
8. Verification: static analysis, unit tests, database tests, RLS tests, concurrent last-item sale test, duplicate retry test, network outage test, Windows build and Android build on actual target devices.
9. Cutover: perform a reviewed data migration from existing Hive export; reconcile product counts, stock balances, invoices, payments, returns, and supplier/customer balances before the new system is used for live sales.

## Required acceptance tests
- Two cashier sessions attempt to sell the final unit concurrently: at most one sale is accepted.
- Repeating the same sale request with the same idempotency key creates exactly one invoice and one stock movement set.
- Different users cannot read or mutate data outside their assigned shop or permission scope.
- A request without connectivity cannot be shown as an accepted sale.
- Failure during invoice/stock processing leaves no partial financial or stock writes.
- Issued invoices and inventory movements remain auditable after correction or cancellation.
- Export then restore reproduces matching business counts and balances.
- flutter analyze, all relevant tests, database/RLS tests, and Windows/Android builds must pass before Hive is removed.

## Free-tier safeguards
- Do not create Supabase paid compute branches or enable billing.
- Monitor quotas and provide a clear blocked-service state if a free quota is reached.
- Keep a tested export path and store backup copies outside the Supabase project.
- Supabase Free has no contractual uptime guarantee; low monthly data usage does not remove the possibility of inactivity pausing or provider-side limits.
- Do not promise that the cloud service will remain free forever.

## Current status
This document records the approved migration strategy. It does not claim that application code, SQL migrations, security policies, or builds have already been changed or tested. The implementation must proceed in small reviewed commits; the Hive implementation must not be deleted before the replacement is complete.