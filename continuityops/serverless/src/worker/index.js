import {
  buildIdempotencyKey,
  isDuplicate,
  markProcessed,
} from './idempotency.js';
import { parseRecordBody } from './parse.js';

/**
 * Lambda timeout vs SQS visibility timeout
 * -----------------------------------------
 * Set queue visibility timeout to at least 6x the Lambda timeout so a slow
 * cold start or downstream stall does not surface the same message to another
 * consumer before the in-flight invocation finishes or times out.
 *
 * Reserved concurrency
 * --------------------
 * Cap worker concurrency per tenant or per queue so a surge cannot exhaust
 * account concurrency or stampede shared dependencies. Pair with partial batch
 * responses so successful records are not retried when one record fails.
 */

/**
 * @param {'debug'|'info'|'warn'|'error'} level
 * @param {string} correlationId
 * @param {string} message
 * @param {Record<string, unknown>} [fields]
 */
export function log(level, correlationId, message, fields = {}) {
  console.log(
    JSON.stringify({
      level,
      correlation_id: correlationId,
      message,
      service: 'continuityops-event-worker',
      timestamp: new Date().toISOString(),
      ...fields,
    }),
  );
}

/**
 * @param {import('aws-lambda').SQSRecord} record
 * @param {string} correlationId
 */
export async function processRecord(record, correlationId) {
  const idempotencyKey = buildIdempotencyKey(record.messageId, record.body);

  if (isDuplicate(idempotencyKey)) {
    log('info', correlationId, 'duplicate message skipped', {
      message_id: record.messageId,
      idempotency_key: idempotencyKey,
    });
    return { status: 'duplicate' };
  }

  const payload = parseRecordBody(record.body, record.messageId);

  log('info', correlationId, 'processing event', {
    message_id: record.messageId,
    event_type: typeof payload === 'object' && payload !== null && 'type' in payload
      ? String(/** @type {{ type?: unknown }} */ (payload).type)
      : 'unknown',
  });

  // Lab synthetic handler: acknowledge structured payloads only.
  if (typeof payload !== 'object' || payload === null) {
    const error = new Error('Event payload must be a JSON object');
    error.name = 'PoisonMessageError';
    throw error;
  }

  markProcessed(idempotencyKey);

  log('info', correlationId, 'event processed', {
    message_id: record.messageId,
    idempotency_key: idempotencyKey,
  });

  return { status: 'processed', idempotencyKey };
}

/**
 * @param {import('aws-lambda').SQSEvent} event
 * @param {import('aws-lambda').Context} [context]
 */
export async function handler(event, context) {
  const requestId = context?.awsRequestId ?? 'local';
  const batchItemFailures = [];

  log('info', requestId, 'batch received', {
    record_count: event.Records.length,
  });

  for (const record of event.Records) {
    const correlationId =
      record.messageAttributes?.correlation_id?.stringValue ?? record.messageId;

    try {
      await processRecord(record, correlationId);
    } catch (error) {
      const err = /** @type {Error & { name?: string }} */ (error);
      if (err.name === 'PoisonMessageError') {
        log('error', correlationId, 'poison message rejected', {
          message_id: record.messageId,
          error: err.message,
        });
        batchItemFailures.push({ itemIdentifier: record.messageId });
        continue;
      }

      log('error', correlationId, 'record processing failed', {
        message_id: record.messageId,
        error: err.message,
      });
      throw err;
    }
  }

  return { batchItemFailures };
}
