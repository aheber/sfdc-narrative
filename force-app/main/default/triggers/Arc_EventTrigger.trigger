trigger Arc_EventTrigger on Arc_Event__e(after insert) {
  Arc_EventTriggerHandler.processLogEvents();
}
