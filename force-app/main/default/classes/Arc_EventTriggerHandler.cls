public with sharing class Arc_EventTriggerHandler {
  public static void processLogEvents() {
    List<Arc__c> arcs = new List<Arc__c>();
    for (SObject l : Trigger.new) {
      arcs.add(buildLogFromEvent((Arc_Event__e) l));
    }
    insert arcs;
  }

  private static Arc__c buildLogFromEvent(Arc_Event__e a) {
    Arc__c arc = new Arc__c();
    Arc.ArcWrapper w = (Arc.ArcWrapper) JSON.deserialize(
      a.Payload__c,
      Arc.ArcWrapper.class
    );
    arc.User_Id__c = w.currentUserId;
    arc.Acting_User_Id__c = w.drivingUserId;
    arc.Build_CPU_Time__c = Double.valueOf(w.eventBuildCPUTime);
    arc.Build_Query_Usage__c = Double.valueOf(w.eventBuildSOQLQueries);
    arc.Class_Name__c = w.className;
    arc.Method_Name__c = w.methodName;
    arc.Line_Number__c = Double.valueOf(w.lineNum);
    arc.Quiddity__c = w.quiddity;
    arc.Request_Id__c = w.requestId;
    arc.Timestamp__c = Datetime.newInstance(w.timestamp);
    arc.Log_Number__c = w.logNumber;
    arc.Transaction_Limits__c = JSON.serialize(w.transactionLimits);
    arc.Exception_Type__c = w.exceptionType;
    arc.Exception_Message__c = w.exceptionMessage;
    arc.Exception_Cause__c = w.exceptionCause;
    arc.Exception_Line_Number__c = w.exceptionLineNumber;
    arc.Exception_Stack__c = w.exceptionStack;
    arc.Message__c = w.message;
    arc.Details__c = w.details;
    arc.Record_Context__c = w.recordContext;
    arc.Log_Level__c = w.logLevel;
    arc.Stack_Trace__c = w.stackTrace;
    arc.Session_Id__c = w.sessionId;
    arc.Root_Session_Id__c = w.rootSessionId;
    arc.Public_IP_Address__c = w.publicIpAddress;
    return arc;
  }
}
