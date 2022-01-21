@SuppressWarnings('PMD.AvoidGlobalModifier') // Apex REST must be Global
@RestResource(urlMapping='/narrative')
global with sharing class NarrativeApi {
  @HttpPost
  global static void doPost() {
    RestResponse rr = RestContext.response;
    String jsonBody = RestContext.request.requestBody.toString();
    try {
      List<Object> arcEntries = (List<Object>) JSON.deserializeUntyped(
        jsonBody
      );
      Integer cnt = 0;

      for (Object objArc : arcEntries) {
        Map<String, Object> arcData = (Map<String, Object>) objArc;
        Arc a = new Arc();
        a.overrideProperties(arcData);
        a.queue();
        cnt++;
      }
      Arc.flush();

      rr.statusCode = 200;
      rr.responseBody = Blob.valueOf(
        JSON.serialize(
          new Map<String, Object>{ 'success' => true, 'arcsAdded' => cnt }
        )
      );
    } catch (Exception e) {
      Arc.exception(e);
      rr.statusCode = 400;
      rr.responseBody = Blob.valueOf(
        JSON.serialize(
          new Map<String, Object>{
            'success' => false,
            'errorMessage' => e.getMessage()
          }
        )
      );
    }
  }
}
