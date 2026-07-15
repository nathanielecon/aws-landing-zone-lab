import { createHash } from 'node:crypto';

/**
 * Lab-only in-memory idempotency store.
 *
 * Production would persist keys in DynamoDB (partition: tenant_id, sort: idempotency_key)
 * with a TTL aligned to the replay window. Conditional writes prevent double-processing
 * across Lambda invocations and reserved concurrency shards.
 */
const processed = new Map();

/**
 * @param {string} messageId SQS message identifier
 * @param {string} payload Raw message body used for content-addressed deduplication
 * @returns {string}
 */
export function buildIdempotencyKey(messageId, payload) {
  const digest = createHash('sha256').update(payload, 'utf8').digest('hex');
  return `${messageId}#${digest}`;
}

/**
 * @param {string} key
 * @returns {boolean}
 */
export function isDuplicate(key) {
  return processed.has(key);
}

/**
 * @param {string} key
 */
export function markProcessed(key) {
  processed.set(key, { processedAt: new Date().toISOString() });
}

/**
 * Test-only reset. Never call from the Lambda handler.
 */
export function resetIdempotencyStoreForTests() {
  processed.clear();
}
