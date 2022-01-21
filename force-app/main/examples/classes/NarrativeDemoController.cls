public with sharing class NarrativeDemoController {
  @AuraEnabled
  public static void successWithLogging(String message) {
    Arc.info(message);
  }

  @AuraEnabled
  public static void failureWithLogging(String message) {
    try {
      update new User();
    } catch (Exception e) {
      new Arc(LoggingLevel.ERROR)
        .setMessage(message)
        .setException(e)
        .addDetail(
          'countOfUsers',
          [SELECT COUNT(Id) FROM User WHERE IsActive = TRUE]
        )
        .write();
    }
  }

  @AuraEnabled
  public static void successWithFailingQueueable(String message) {
    System.enqueueJob(new NarrativeTestQueueable(message));
  }

  public class NarrativeTestQueueable implements Queueable {
    String message;
    public NarrativeTestQueueable(String message) {
      this.message = message;
    }

    public void execute(QueueableContext ctx) {
      Arc.ArcFinalizer f = new Arc.ArcFinalizer();
      f.arcEntry.setMessage(this.message);
      System.attachFinalizer(f);
      update new User();
    }
  }
}
