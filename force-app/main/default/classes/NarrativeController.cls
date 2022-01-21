public with sharing class NarrativeController {
  @AuraEnabled
  public static void commitArcs(List<Map<String, Object>> arcsData) {
    try {
      for (Map<String, Object> arcData : arcsData) {
        Arc a = new Arc();
        a.overrideProperties(arcData);
        a.queue();
      }
      Arc.flush();
    } catch (Exception e) {
      Arc.exception(e);
      throw e;
    }
  }
}
