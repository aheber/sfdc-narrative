# Why?

Why add a new logging framework? I found a lot of the existing logging frameworks difficult to leverage, complicated to manage, or not leveraging recent platform features invaluable to logging.

Narrative is a logging framework built to use the latest features of the Salesforce platform to construct a robust logging pattern that includes as much information as possible and makes it easy to add simple logging while having the power to break out to advanced logging entries with rich subsets of data.

Every Arc Log includes information for what class, method, and line it was invoked from. What the Request context is. Context User, and where avilable running/driving user for Login-As contexts. Limits data. It also reports how much CPU & SOQL were consumed during logging execution.

## Basic Logging

Our most simple logging is using the short-hand methods on the Arc class.

```Apex
Arc.info('Hello, world!');
Arc.debug('Hello, world!');
Arc.warn('Hello, world!');
Arc.error('Hello, world!');
Arc.exception(e);
```

If you need to add more information or want to control the flush/commit cycles then you can instantiate Arc instances and using a Fluent API manipulate them before finalizing.

```Apex
Arc a = new Arc().addDetail('param1', paramValue);
a.addValue(value1);
a.addValue(value2);
a.addValue(value3).addValue(value4);
a.queue();

new Arc(LoggingLevel.ERROR).addException(e).addDetail('param1', paramValue).addValue(value1).write();
// Every write() actions writes the current and all pending queued Arcs to the Event Bus
```

\*Please note that if you don't specifically queue and eventually write the Arcs then they will never be published to the Event Bus and will never make it to your final logs. Creating the object is not enough, it must be finalized somehow at the end of the day.

\*In testing the initial Arc in a transaction will cost 0-1 SOQL queries and ~30MS of CPU time. Subsequent Arcs should cost 0 SOQL and 1-2MS of CPU time. (self-reported by the framework)
