Feature: Visitor Rotation - Unit Test

Background:
  * def visitorRotation = read('classpath:com/preezie/services/utils/visitor-rotation.js')

Scenario: Visitor rotation should automatically switch IDs when limit is reached
  # Initialize with limit of 3 messages
  * def initialId = visitorRotation.initialize('test_visitor', 3)
  * match initialId == 'test_visitor'

  # Get ID for messages 1-3 (should be same ID)
  * def id1 = visitorRotation.getNextVisitorId()
  * match id1 == 'test_visitor'
  * visitorRotation.recordMessageSent()

  * def id2 = visitorRotation.getNextVisitorId()
  * match id2 == 'test_visitor'
  * visitorRotation.recordMessageSent()

  * def id3 = visitorRotation.getNextVisitorId()
  * match id3 == 'test_visitor'
  * visitorRotation.recordMessageSent()

  # Message 4 should trigger rotation to test_visitor_1
  * def id4 = visitorRotation.getNextVisitorId()
  * match id4 == 'test_visitor_1'
  * visitorRotation.recordMessageSent()

  # Message 5-6 should stay on test_visitor_1
  * def id5 = visitorRotation.getNextVisitorId()
  * match id5 == 'test_visitor_1'
  * visitorRotation.recordMessageSent()

  * def id6 = visitorRotation.getNextVisitorId()
  * match id6 == 'test_visitor_1'
  * visitorRotation.recordMessageSent()

  # Message 7 should rotate to test_visitor_2
  * def id7 = visitorRotation.getNextVisitorId()
  * match id7 == 'test_visitor_2'

  # Verify stats
  * def stats = visitorRotation.getStats()
  * match stats.baseVisitorId == 'test_visitor'
  * match stats.currentVisitorId == 'test_visitor_2'
  * match stats.rotationIndex == 2
  * match stats.messageCount == 0
  * match stats.rotationLimit == 3

  * print 'Visitor rotation test passed! ✅'

Scenario: Auto-generate visitor ID when base is not provided
  * visitorRotation.reset()
  * def autoId = visitorRotation.initialize(null, 5)
  * match autoId contains 'visitor_auto_'
  * print 'Auto-generated visitorId:', autoId

Scenario: Reset should clear state
  * visitorRotation.reset()
  * def newId = visitorRotation.initialize('fresh_visitor', 10)
  * match newId == 'fresh_visitor'
  * def stats = visitorRotation.getStats()
  * match stats.messageCount == 0
  * match stats.rotationIndex == 0
  * print 'Reset test passed! ✅'

