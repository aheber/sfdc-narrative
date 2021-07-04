@SuppressWarnings('PMD.ExcessivePublicCount,PMD.TooManyFields')
public without sharing class Arc {
  // regex pattern to decompose the stack trace
  private static final Pattern STACK_LINE = Pattern.compile(
    '\\w+ (\\d+), \\w+ (\\d+)'
  );

  // static properties
  private static final String CLASS_NAME;
  private static final String ROOT_SESSION_ID;
  private static final String SESSION_ID_HASH;
  private static final String DRIVING_USER_ID;
  private static final String PUBLIC_IP_ADDRESS;
  private static final Request REQ_INFO;
  @TestVisible
  private static List<ArcWrapper> arcQueue = new List<ArcWrapper>();
  private static String logLevel;
  private static Integer logNum = 1; // incremented with each log
  private static Integer unownedSoqlCost;
  private static Integer unownedCpuCost;

  // instance properties
  private final ArcWrapper lw;
  private LoggingLevel level;
  private Boolean forceLog = false;
  @TestVisible
  private Map<String, Object> details;
  @TestVisible
  private List<Object> values;
  private Integer startCpuTime;
  private Integer startSoqlCount;

  // singleton initializer for unchanging data valid for the entire transaction
  static {
    // snapshot the current limits values so we can track change
    Integer startingSoqlCount = Limits.getQueries();
    Integer startingCpuTime = Limits.getCpuTime();
    logLevel = getLogLevel();
    CLASS_NAME = Arc.class.getName();
    REQ_INFO = Request.getCurrent();
    SESSION_ID_HASH = getSessionHash();
    Map<String, String> s = getRootSession();
    ROOT_SESSION_ID = s.get('SessionId');
    PUBLIC_IP_ADDRESS = s.get('SourceIp');
    DRIVING_USER_ID = getDrivingUser(s.get('UsersId'));
    // executed at the end of the block to record how long it took to execute the block
    unownedSoqlCost = Limits.getQueries() - startingSoqlCount;
    unownedCpuCost = Limits.getCpuTime() - startingCpuTime;
  }

  // short hand to create an Arc at a specific level or type
  public static void info(String message) {
    new Arc(LoggingLevel.INFO).setMessage(message).write();
  }

  public static void debug(String message) {
    new Arc(LoggingLevel.DEBUG).setMessage(message).write();
  }

  public static void warn(String message) {
    new Arc(LoggingLevel.WARN).setMessage(message).write();
  }

  public static void error(String message) {
    new Arc(LoggingLevel.ERROR).setMessage(message).write();
  }

  public static void exception(Exception e) {
    new Arc(LoggingLevel.ERROR).setException(e).write();
  }

  public Arc() {
    this(LoggingLevel.DEBUG);
  }

  public Arc(LoggingLevel level) {
    lw = new ArcWrapper();
    setLogLevel(level);
    // capture performance data of the act of logging
    startCpuTime = Limits.getCpuTime();
    startSoqlCount = Limits.getQueries();
    // build of the supporting data and other baselines
    details = new Map<String, Object>();
    values = new List<Object>();
    lw.logNumber = logNum++;
    lw.timestamp = getTimestamp();
    populateLimits();
    populateUserDetails();
    populateStackInfo();
    populateRequestDetails();
  }

  public Arc setLogLevel(LoggingLevel level) {
    this.level = level;
    lw.logLevel = level.name();
    return this;
  }

  public Arc setMessage(String message) {
    lw.message = message;
    return this;
  }

  public Arc setContext(String contextId) {
    lw.recordContext = contextId;
    return this;
  }

  public Arc setException(Exception e) {
    if (e != null) {
      lw.exceptionType = e.getTypeName();
      lw.exceptionMessage = e.getMessage();
      lw.exceptionCause = '' + e.getCause();
      lw.exceptionLineNumber = e.getLineNumber();
      lw.exceptionStack = e.getStackTraceString();
    }
    return this;
  }

  public Arc addValue(Object o) {
    values.add(o);
    return this;
  }

  public Arc addDetail(String name, Object o) {
    details.put(name, o);
    return this;
  }

  public Arc forceLogging() {
    return setForceLogging(true);
  }

  public Arc setForceLogging(Boolean f) {
    forceLog = f;
    return this;
  }

  // used to commit the log entry to the memory queue to be flushed
  // if Arc.flush() or another event's write() method are never called, this event is not recorded
  public void queue() {
    if (
      forceLog == false &&
      getNumForLogLevel(lw.logLevel) > getNumForLogLevel(logLevel)
    ) {
      return; // Not logging at this level
    }

    populateDetails();
    if (
      Limits.getPublishImmediateDML() >= Limits.getLimitPublishImmediateDML()
    ) {
      // Exhausted event limits, doing our best
      System.debug(level, lw.message + '--' + lw.details);
      return;
    }
    populatePerfDetails();
    arcQueue.add(lw);
  }

  // Can be called to immediately write the Arc to the EventBus
  public void write() {
    queue();
    Arc.flush();
  }

  // Can be called anytime to flush any queued arcs to the EventBus
  public static void flush() {
    try {
      if (arcQueue.isEmpty()) {
        return;
      }
      List<Arc_Event__e> events = new List<Arc_Event__e>();
      for (ArcWrapper l : arcQueue) {
        events.add(new Arc_Event__e(Payload__c = JSON.serialize(l)));
      }
      EventBus.publish(events);
      arcQueue.clear();
    } catch (Exception ex) {
      System.debug('Flush failed:' + ex.getMessage());
    }
  }

  public static void setSystemLogLevel(LoggingLevel level) {
    setSystemLogLevel(level.name());
  }

  public static void setSystemLogLevel(String level) {
    logLevel = level;
  }

  // PRIVATE

  private void populateUserDetails() {
    lw.currentUserId = UserInfo.getUserId();
    lw.drivingUserId = DRIVING_USER_ID;
    lw.rootSessionId = ROOT_SESSION_ID;
    lw.sessionId = SESSION_ID_HASH;
    lw.publicIpAddress = PUBLIC_IP_ADDRESS;
  }

  private void populateStackInfo() {
    // Idea taken from https://salesforce.stackexchange.com/questions/153835
    List<String> stacktrace = new DmlException()
      .getStackTraceString()
      .split('\n');

    // trim off self-referencing stack lines
    for (Integer i = stacktrace.size() - 1; i >= 0; i--) {
      if (stacktrace.get(i).startsWith('Class.' + CLASS_NAME + '.')) {
        stacktrace.remove(i);
      }
    }
    // capture the remaining stack trace
    lw.stackTrace = String.join(stacktrace, '\n');

    Map<String, String> stackData = decomposeStackLine(stacktrace[0]);
    lw.className = stackData.get('class');
    lw.methodName = stackData.get('method');
    lw.lineNum = stackData.get('lineNum');
  }

  private void populateDetails() {
    // If we don't have any additional context, leave empty
    if (details.keySet().isEmpty() && values.isEmpty()) {
      return;
    }
    // If we have array of values, merge into details
    // THIS WILL OVERRWRITE ANY "details" named "_values"
    if (!values.isEmpty()) {
      details.put('_values', values);
    }
    // Serialize for transmission
    lw.details = JSON.serialize(details);
  }

  // invoked just before this entry is queued
  private void populatePerfDetails() {
    // First arc accepts the "setup" cost from the static initializers
    // we determine
    lw.eventBuildCPUTime =
      (Limits.getCpuTime() - startCpuTime) + unownedCpuCost;
    lw.eventBuildSOQLQueries =
      (Limits.getQueries() - startSoqlCount) + unownedSoqlCost;
    unownedCpuCost = 0;
    unownedSoqlCost = 0;
  }

  private void populateRequestDetails() {
    lw.requestId = REQ_INFO.getRequestId();
    lw.quiddity = REQ_INFO.getQuiddity().name();
  }

  // Static support methods

  public static long getTimestamp() {
    return System.now().getTime();
  }

  private static Map<String, String> decomposeStackLine(String s) {
    // Split into method path and line-column
    List<String> lineParts = s.split(':');
    // Break the method into parts
    List<String> pathParts = lineParts[0].split('\\.');
    // Pop the leading "Class" text
    if ('Class'.equals(pathParts.get(0))) {
      pathParts.remove(0);
    }
    // pull the method name from the tip of the list
    String method = pathParts.remove(pathParts.size() - 1);
    // build the classname from the remaining parts
    String className = String.join(pathParts, '.');
    // if the classname was empty, probably Anon Apex, copy the value back
    if (String.isEmpty(className)) {
      className = method;
    }
    // retrieve the line number
    Matcher matcher = STACK_LINE.matcher(lineParts[1].trim());
    matcher.find();
    String lineNum = matcher.group(1);
    String columnNum = matcher.group(2);
    // build the return object
    return new Map<String, String>{
      'class' => className,
      'method' => method,
      'lineNum' => lineNum,
      'columNum' => columnNum
    };
  }

  private static String getLogLevel() {
    // If you have configuration management employed in your org
    // you can use that to manage the default logging level here
    return LoggingLevel.ERROR.name();
  }

  // convert the session to a hash so we can correlate but don't expose the actual hash
  private static String getSessionHash() {
    String sessionId = UserInfo.getSessionId();
    if (String.isBlank(sessionId)) {
      return null;
    }
    Blob myBlob = Blob.valueOf(UserInfo.getSessionId());
    Blob md5hash = Crypto.generateDigest('MD5', myBlob);
    return EncodingUtil.convertToHex(md5hash);
  }

  private static Map<String, String> getRootSession() {
    Map<String, String> aMap = Auth.SessionManagement.getCurrentSession();
    Map<String, String> sDetails = new Map<String, String>();
    for (String k : aMap.keySet()) {
      sDetails.put(k, aMap.get(k));
    }
    Set<String> parentSessionIds = new Set<String>();
    // If we have a "root" session that doesn't have a parent ID attached to our user, return that one
    if (String.isBlank(sDetails.get('ParentId'))) {
      if (sDetails.get('SessionType') == 'SubstituteUser') {
        // This is a Login As session but we don't know who is the acting user
        sDetails.put('UsersId', '[unknown]');
      }
      return sDetails;
    }
    parentSessionIds.add(sDetails.get('ParentId'));
    // We have sessions so there is a user logged in
    // we don't have a standalone root session attached to this user
    // that should indicate that we're actually attached to a different root session that isn't tagged to our user
    // works for community login as but not core platform
    if (parentSessionIds.isEmpty()) {
      return getDataMapFromSession(null);
    }
    List<AuthSession> sessions = [
      SELECT Id, SourceIp, UsersId
      FROM AuthSession
      WHERE Id IN :parentSessionIds AND ParentId = NULL
    ];
    if (sessions.isEmpty()) {
      return getDataMapFromSession(null); // not sure why/where we got lost, giving up
    }
    return getDataMapFromSession(sessions[0]); // return the root session that we're not attached to
  }

  private static Map<String, String> getDataMapFromSession(AuthSession s) {
    Map<String, String> data = new Map<String, String>();
    if (s == null) {
      return data;
    }
    data.put('SessionId', s.Id);
    data.put('UserType', s.UserType);
    data.put('ParentId', s.ParentId);
    data.put('NumSecondsValid', String.valueOf(s.NumSecondsValid));
    data.put('LoginType', s.LoginType);
    data.put('LoginHistoryId', s.LoginHistoryId);
    data.put('CreatedDate', String.valueOf(s.CreatedDate));
    data.put('SessionType', s.SessionType);
    data.put('LastModifiedDate', String.valueOf(s.LastModifiedDate));
    data.put('LogoutUrl', s.LogoutUrl);
    data.put('SessionSecurityLevel', s.SessionSecurityLevel);
    data.put('UsersId', s.UsersId);
    data.put('SourceIp', s.SourceIp);
    return data;
  }

  private static String getDrivingUser(String s) {
    if (s != null && s != UserInfo.getUserId()) {
      // using Salesforce Login As, root session is from the initiating user
      return s;
    }
    return null; // no known alterante driving user, must be genuine login by the known user
  }

  private void populateLimits() {
    lw.transactionLimits = getLimitsMap();
  }

  // assign numeric value to logginglevel so we can decide if the
  // level of an even is lower that the limit
  // probably a better way to accomplish this using the ENUM value
  private static Integer getNumForLogLevel(String level) {
    switch on level.toUpperCase() {
      when 'NONE' {
        return 0;
      }
      when 'ERROR' {
        return 1;
      }
      when 'WARN' {
        return 2;
      }
      when 'INFO' {
        return 3;
      }
      when 'DEBUG' {
        return 4;
      }
      when 'FINE' {
        return 5;
      }
      when 'FINER' {
        return 6;
      }
      when 'FINEST' {
        return 7;
      }
      when else {
        return -1;
      }
    }
  }

  // When benchmarked, this process took ~0.5 milliseconds to complete as-is
  public static Map<String, Integer> getLimitsMap() {
    Map<String, Integer> limitsData = new Map<String, Integer>();
    limitsData.put('AggregateQueries', Limits.getAggregateQueries());
    limitsData.put('LimitAggregateQueries', Limits.getLimitAggregateQueries());
    limitsData.put('AsyncCalls', Limits.getAsyncCalls());
    limitsData.put('LimitAsyncCalls', Limits.getLimitAsyncCalls());
    limitsData.put('Callouts', Limits.getCallouts());
    limitsData.put('LimitCallouts', Limits.getLimitCallouts());
    limitsData.put('CpuTime', Limits.getCpuTime());
    limitsData.put('LimitCpuTime', Limits.getLimitCpuTime());
    limitsData.put('DMLRows', Limits.getDMLRows());
    limitsData.put('LimitDMLRows', Limits.getLimitDMLRows());
    limitsData.put('DMLStatements', Limits.getDMLStatements());
    limitsData.put('LimitDMLStatements', Limits.getLimitDMLStatements());
    limitsData.put('EmailInvocations', Limits.getEmailInvocations());
    limitsData.put('LimitEmailInvocations', Limits.getLimitEmailInvocations());
    limitsData.put('FutureCalls', Limits.getFutureCalls());
    limitsData.put('LimitFutureCalls', Limits.getLimitFutureCalls());
    limitsData.put('HeapSize', Limits.getHeapSize());
    limitsData.put('LimitHeapSize', Limits.getLimitHeapSize());
    limitsData.put('MobilePushApexCalls', Limits.getMobilePushApexCalls());
    limitsData.put(
      'LimitMobilePushApexCalls',
      Limits.getLimitMobilePushApexCalls()
    );
    limitsData.put('PublishImmediateDML', Limits.getPublishImmediateDML());
    limitsData.put(
      'LimitPublishImmediateDML',
      Limits.getLimitPublishImmediateDML()
    );
    limitsData.put('Queries', Limits.getQueries());
    limitsData.put('LimitQueries', Limits.getLimitQueries());
    limitsData.put('QueryLocatorRows', Limits.getQueryLocatorRows());
    limitsData.put('LimitQueryLocatorRows', Limits.getLimitQueryLocatorRows());
    limitsData.put('QueryRows', Limits.getQueryRows());
    limitsData.put('LimitQueryRows', Limits.getLimitQueryRows());
    limitsData.put('QueueableJobs', Limits.getQueueableJobs());
    limitsData.put('LimitQueueableJobs', Limits.getLimitQueueableJobs());
    limitsData.put('SoslQueries', Limits.getSoslQueries());
    limitsData.put('LimitSoslQueries', Limits.getLimitSoslQueries());
    return limitsData;
  }

  public class ArcWrapper {
    public Id currentUserId; // User Id of the current context user
    public String drivingUserId; // Acting User Id if the session was initiated via proxy
    public Integer eventBuildCPUTime; // track the CPU build time of the event
    public Integer eventBuildSOQLQueries; // track the SOQL queries used to build the event
    public String className; // The class name that emitted the arc event
    public String methodName; // The method name that emmitted the arc event
    public String lineNum; // The line number that emitted the arc event
    // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_class_System_Request.htm
    public String quiddity; // Enum representing how Apex is running. e.g. BULK_API vs LIGHTNING
    public String requestId; // the identifier for this request, which is universally unique
    public long timestamp; // moment the arc event was emitted
    public Integer logNumber;
    public Map<String, Integer> transactionLimits; // current snapshot of limit data
    public String exceptionType;
    public String exceptionMessage;
    public String exceptionCause;
    public Integer exceptionLineNumber;
    public String exceptionStack;
    public String message;
    public String details; // messages and objects stringified into the log, stored as JSON
    public String recordContext; // if applicable, the identifier of the record involved in the current request
    public String logLevel; // LoggingLevel value (DEBUG, INFO, WARN, ERROR, ETC...)
    public String stackTrace; // How we got to this emit
    public String sessionId; // hash of the current sessionId, used to tied multiple transactions to a user session
    public String rootSessionId; // the AuthSession identifier for the root of this session
    public String publicIpAddress;
  }
}
