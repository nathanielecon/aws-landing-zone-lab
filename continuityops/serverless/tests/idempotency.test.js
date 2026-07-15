import assert from 'node:assert/strict';
import { describe, it, beforeEach } from 'node:test';
import {
  buildIdempotencyKey,
  isDuplicate,
  markProcessed,
  resetIdempotencyStoreForTests,
} from '../src/worker/idempotency.js';

describe('idempotency', () => {
  beforeEach(() => {
    resetIdempotencyStoreForTests();
  });

  it('builds a stable key from messageId and payload hash', () => {
    const keyA = buildIdempotencyKey('msg-1', '{"tenant":"t1"}');
    const keyB = buildIdempotencyKey('msg-1', '{"tenant":"t1"}');
    const keyC = buildIdempotencyKey('msg-1', '{"tenant":"t2"}');

    assert.equal(keyA, keyB);
    assert.notEqual(keyA, keyC);
    assert.match(keyA, /^msg-1#[a-f0-9]{64}$/);
  });

  it('treats unmarked keys as new work', () => {
    const key = buildIdempotencyKey('msg-2', '{}');
    assert.equal(isDuplicate(key), false);
  });

  it('detects duplicates after markProcessed', () => {
    const key = buildIdempotencyKey('msg-3', '{"event":"onboard"}');
    markProcessed(key);
    assert.equal(isDuplicate(key), true);
  });
});
