/**
 * Poison messages are bodies that cannot be parsed as JSON. Once detected, the
 * messageId is marked so retries fail fast and the record redrives to the DLQ
 * after maxReceiveCount without wasting handler time on unrecoverable payloads.
 */
const poisonMessageIds = new Set();

/**
 * @param {string} messageId
 * @returns {boolean}
 */
export function isPoisonMessage(messageId) {
  return poisonMessageIds.has(messageId);
}

/**
 * @param {string} body
 * @param {string} messageId
 * @returns {unknown}
 */
export function parseRecordBody(body, messageId) {
  if (poisonMessageIds.has(messageId)) {
    throw createPoisonError(messageId, 'already marked poison');
  }

  try {
    return JSON.parse(body);
  } catch (cause) {
    poisonMessageIds.add(messageId);
    const error = createPoisonError(messageId, 'invalid JSON body');
    error.cause = cause;
    throw error;
  }
}

/**
 * @param {string} messageId
 * @param {string} reason
 * @returns {Error}
 */
function createPoisonError(messageId, reason) {
  const error = new Error(`Poison message (${messageId}): ${reason}`);
  error.name = 'PoisonMessageError';
  error.messageId = messageId;
  return error;
}

/**
 * Test-only reset. Never call from the Lambda handler.
 */
export function resetPoisonRegistryForTests() {
  poisonMessageIds.clear();
}
