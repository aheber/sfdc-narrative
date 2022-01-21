@isTest(isParallel=true)
public class NarrativeApi_Test {
  @isTest
  public static void testSuccess() {
    List<Map<String, Object>> arcs = new List<Map<String, Object>>();
    arcs.add(new Map<String, Object>{ 'quiddity' => 'EXTERNAL' });
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.httpMethod = 'POST';
    req.requestURI = '/narrative';
    req.requestBody = Blob.valueOf(JSON.serialize(arcs));
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    NarrativeApi.doPost();
    Test.stopTest();
    System.assertEquals(
      200,
      res.statusCode,
      'Expected success code, error: ' + res.responseBody.toString()
    );
    // TODO: Check the Narrative platform event and confirm values were delivered as expected
  }

  @isTest
  public static void testFailure() {
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.httpMethod = 'POST';
    req.requestURI = '/narrative';
    req.requestBody = Blob.valueOf('Hello world');
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    NarrativeApi.doPost();
    Test.stopTest();
    System.assertEquals(
      400,
      res.statusCode,
      'Expected error code, error: ' + res.responseBody.toString()
    );
    // TODO: Check the Narrative platform event and confirm values were delivered as expected
  }
}
