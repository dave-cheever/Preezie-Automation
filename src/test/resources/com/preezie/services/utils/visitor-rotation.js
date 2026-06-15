// visitor-rotation.js
// Automatically rotates visitorId when message limit is reached
// Prevents hitting the chat widget's per-visitor message limit during testing

(function() {

  /**
   * Initialize the visitor rotation system
   * @param {string} baseVisitorId - The base visitor ID to use (will append _1, _2, etc. for rotations)
   * @param {number} rotationLimit - Number of messages before rotating to a new visitorId
   * @returns {string} The initial visitorId to use
   */
  function initialize(baseVisitorId, rotationLimit) {
    var base = baseVisitorId || ('visitor_auto_' + java.lang.System.currentTimeMillis());
    var limit = rotationLimit || 10;

    karate.set('__vrBaseId', base);
    karate.set('__vrLimit', limit);
    karate.set('__vrCount', 0);
    karate.set('__vrIndex', 0);

    karate.log('[VisitorRotation] Initialized - Base:', base, '| Limit:', limit);
    return base;
  }

  /**
   * Get the next visitorId to use (rotates if limit reached)
   * Call this BEFORE sending each message
   * @returns {string} The visitorId to use for the next message
   */
  function getNextVisitorId() {
    var base = karate.get('__vrBaseId');
    var limit = karate.get('__vrLimit') || 10;
    var count = karate.get('__vrCount') || 0;
    var index = karate.get('__vrIndex') || 0;

    // Check if we need to rotate
    if (count >= limit) {
      index++;
      count = 0;
      karate.set('__vrIndex', index);
      karate.set('__vrCount', count);

      var newId = (index === 0) ? base : (base + '_' + index);
      karate.log('[VisitorRotation] 🔄 Rotating to:', newId, '(rotation #' + index + ')');
      return newId;
    }

    // Return current ID
    return (index === 0) ? base : (base + '_' + index);
  }

  /**
   * Record that a message was sent successfully
   * Call this AFTER each successful message send
   * Increments the counter and may trigger rotation on next call to getNextVisitorId()
   */
  function recordMessageSent() {
    var base = karate.get('__vrBaseId');
    var limit = karate.get('__vrLimit') || 10;
    var count = karate.get('__vrCount') || 0;
    var index = karate.get('__vrIndex') || 0;

    count++;
    karate.set('__vrCount', count);

    var currentId = (index === 0) ? base : (base + '_' + index);
    karate.log('[VisitorRotation] 📊 Count:', count + '/' + limit, '| Current:', currentId);
  }

  /**
   * Force an immediate rotation to the next visitor ID
   * Useful for starting a test run with a fresh visitor ID
   */
  function forceRotation() {
    var base = karate.get('__vrBaseId');
    var index = karate.get('__vrIndex') || 0;

    index++;
    karate.set('__vrIndex', index);
    karate.set('__vrCount', 0); // Reset count for new visitor

    var newId = base + '_' + index;
    karate.log('[VisitorRotation] 🔄 Forced rotation to:', newId, '(rotation #' + index + ')');
    return newId;
  }

  /**
   * Reset the rotation state (useful for starting a new test run)
   */
  function reset() {
    karate.set('__vrBaseId', null);
    karate.set('__vrLimit', null);
    karate.set('__vrCount', null);
    karate.set('__vrIndex', null);
    karate.log('[VisitorRotation] State reset');
  }

  /**
   * Get current rotation statistics for debugging
   * @returns {object} Current state information
   */
  function getStats() {
    var base = karate.get('__vrBaseId');
    var limit = karate.get('__vrLimit') || 10;
    var count = karate.get('__vrCount') || 0;
    var index = karate.get('__vrIndex') || 0;
    var currentId = (index === 0) ? base : (base + '_' + index);

    return {
      baseVisitorId: base,
      currentVisitorId: currentId,
      messageCount: count,
      rotationLimit: limit,
      rotationIndex: index
    };
  }

  return {
    initialize: initialize,
    getNextVisitorId: getNextVisitorId,
    recordMessageSent: recordMessageSent,
    reset: reset,
    getStats: getStats,
    forceRotation: forceRotation
  };

})()
