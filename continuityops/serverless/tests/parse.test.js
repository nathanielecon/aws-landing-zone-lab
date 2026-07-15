import assert from 'node:assert/strict';
import { describe, it, beforeEach } from 'node:test';
import {
  parseRecordBody,
  isPoisonMessage,
  resetPoisonRegistryForTests,
} from '../src/worker/parse.js';
import { processRecord } from '../src/worker/index.js';
import { resetIdempotencyStoreForTests } from '../src/worker/idempotency.js';

describe('parseRecordBody', () => {
  beforeEach(() => {
    resetPoisonRegistryForTests();
  });

  it('parses valid JSON bodies', () => {
    const payload = parseRecordBody('{"type":"tenant.onboard"}', 'msg-valid');
    assert.deepEqual(payload, { type: 'tenant.onboard' });
    assert.equal(isPoisonMessage('msg-valid'), false);
  });

  it('marks invalid JSON as poison and throws PoisonMessageError', () => {
    assert.throws(
      () => parseRecordBody('{not-json', 'msg-poison'),
      (error) => {
        assert.equal(error.name, 'PoisonMessageError');
        assert.equal(error.messageId, 'msg-poison');
        return true;
      },
    );
    assert.equal(isPoisonMessage('msg-poison'), true);
  });

  it('fails fast on retry of a poison message', () => {
    assert.throws(() => parseRecordBody('{bad', 'msg-retry'));
    assert.throws(
      () => parseRecordBody('{"ignored":true}', 'msg-retry'),
      /already marked poison/,
    );
  });
});

describe('processRecord poison handling', () => {
  beforeEach(() => {
    resetPoisonRegistryForTests();
    resetIdempotencyStoreForTests();
  });

  it('reports poison messages through handler batch failures', async () => {
    const event = {
      Records: [
        {
          messageId: 'poison-1',
          body: '<<<invalid>>>',
          messageAttributes: {},
        },
      ],
    };

    const { handler } = await import('../src/worker/index.js');
    const result = await handler(event, { awsRequestId: 'req-1' });

    assert.deepEqual(result.batchItemFailures, [
      { itemIdentifier: 'poison-1' },
    ]);
  });

  it('skips duplicate deliveries without failure', async () => {
    const record = {
      messageId: 'dup-1',
      body: '{"type":"tenant.export"}',
      messageAttributes: { correlation_id: { stringValue: 'corr-dup' } },
    };

    const first = await processRecord(record, 'corr-dup');
    const second = await processRecord(record, 'corr-dup');

    assert.equal(first.status, 'processed');
    assert.equal(second.status, 'duplicate');
  });
});
