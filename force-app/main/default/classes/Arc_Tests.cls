@IsTest
public class Arc_Tests {
  @IsTest
  public static void testConstructors() {
    Arc.setSystemLogLevel(LoggingLevel.DEBUG);
    new Arc().queue();
    new Arc(LoggingLevel.DEBUG).queue();
    new Arc(LoggingLevel.ERROR).queue();
    System.assertEquals(3, Arc.arcQueue.size());
    System.assertEquals(LoggingLevel.DEBUG.name(), Arc.arcQueue[0].logLevel);
    System.assertEquals(LoggingLevel.DEBUG.name(), Arc.arcQueue[1].logLevel);
    System.assertEquals(LoggingLevel.ERROR.name(), Arc.arcQueue[2].logLevel);
  }

  @IsTest
  public static void testLoggingMessage() {
    Arc.setSystemLogLevel(LoggingLevel.DEBUG);
    Test.startTest();
    Arc l = new Arc().setMessage('Hello world');
    System.assertEquals(0, Arc.arcQueue.size(), 'Expected queue to be empty');
    l.queue();
    System.assertEquals(
      1,
      Arc.arcQueue.size(),
      'Expected arc entry to be queued'
    );
    Arc.ArcWrapper w = Arc.arcQueue[0];
    System.assertEquals('Hello world', w.message);
    System.assertEquals(0, Limits.getPublishImmediateDML());
    Arc.flush();
    System.assertEquals(0, Arc.arcQueue.size(), 'Expected queue to be empty');
    System.assertEquals(1, Limits.getPublishImmediateDML());
    Test.stopTest();
  }

  @IsTest
  public static void testExceptionDetails() {
    Arc.setSystemLogLevel(LoggingLevel.DEBUG);
    Arc l = new Arc().setException(new DMLException());
    l.queue();
    Arc.ArcWrapper w = Arc.arcQueue[0];
    System.assertNotEquals(null, w.exceptionMessage);
    System.assertNotEquals(null, w.exceptionType);
    System.assertNotEquals(null, w.exceptionCause);
    System.assertNotEquals(null, w.exceptionLineNumber);
    System.assertNotEquals(null, w.exceptionStack);
  }

  @IsTest
  public static void testStaticMethods() {
    Arc.setSystemLogLevel(LoggingLevel.WARN);
    System.assertEquals(0, Limits.getPublishImmediateDML());
    Test.startTest();
    Arc.debug('Hello world'); // should not log
    Arc.warn('Dang'); // should log
    Arc.error('Broke it again'); // should log
    Arc.exception(new DMLException()); // should log
    System.assertEquals(3, Limits.getPublishImmediateDML());
    Test.stopTest();
  }

  @IsTest
  public static void testAddingInfo() {
    Arc.setSystemLogLevel(LoggingLevel.DEBUG);
    Arc l = new Arc()
      .addValue('Hello world')
      .addValue(12345)
      .addDetail('testing', 'Details')
      .addDetail('more', new Map<String, String>{ 'data' => 'findme' });
    System.assertEquals(2, l.values.size());
    System.assertEquals('Hello world', (String) l.values[0]);
    System.assertEquals(12345, (Integer) l.values[1]);
    System.assertEquals(2, l.details.keySet().size());
    System.assertEquals('Details', l.details.get('testing'));
    System.assertEquals(
      new Map<String, String>{ 'data' => 'findme' },
      (Map<String, String>) l.details.get('more')
    );
    l.queue();
    Arc.ArcWrapper w = Arc.arcQueue[0];
    System.assert(w.details.contains('"values"'));
    System.assert(w.details.contains('"Hello world"'));
    System.assert(w.details.contains('12345'));
    System.assert(w.details.contains('testing'));
    System.assert(w.details.contains('findme'));
  }

  @IsTest
  public static void testForcedLogging() {
    Arc.setSystemLogLevel(LoggingLevel.ERROR);
    new Arc(LoggingLevel.DEBUG).queue();
    System.assertEquals(0, Arc.arcQueue.size());
    new Arc(LoggingLevel.DEBUG).forceLogging().queue();
    System.assertEquals(1, Arc.arcQueue.size());
    System.assertEquals(LoggingLevel.DEBUG.name(), Arc.arcQueue[0].logLevel);
  }
}
