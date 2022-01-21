import commitArcs from "@salesforce/apex/NarrativeController.commitArcs";

/**
 * Parameters
 * @typedef {Object} ArcData
 * @property {string} [className] - The file or component the arc was generated in (auto-discovered where possible).
 * @property {string} [methodName] - The function the arc was generated in (auto-discovered where possible).
 * @property {number} [lineNum] - The line number where the arc was generated at (auto-discovered where possible).
 * @property {string} [stackTrace] - The stack track, excluding the arc class, where the arc was generated from (auto-discovered where possible).
 * @property {string} [quiddity="COMPONENT"] - The Quiddity in a form compatible with the ideas of the Request Apex object, custom values for distinction. Default
 *
 * @property {string} [exceptionType="JavascriptError"] - Categorization only, if there is an error property present then we populate this.
 * @property {string} [exceptionMessage] - Indicates whether the Wisdom component is present.
 * @property {string} [exceptionCause] - Indicates whether the Wisdom component is present.
 * @property {number} [exceptionLineNumber] - Indicates whether the Wisdom component is present.
 * @property {string} [exceptionStack] - Indicates whether the Wisdom component is present.
 *
 * @property {string} [message] - Indicates whether the Wisdom component is present.
 * @property {string} [details] - Indicates whether the Wisdom component is present.
 * @property {string} [recordContext] - Indicates whether the Wisdom component is present.
 * @property {"ERROR"|"WARN"|"INFO"|"DEBUG"|"TRACE"} [logLevel] - Indicates whether the Wisdom component is present.
 */

const defaultData = {
  quiddity: "COMPONENT",
  logLevel: "TRACE" // should match the string values of the LoggingLevel enum in apex
};

/**
 * Generate a arc entry and send it to Salesforce
 * defaults to logLevel of "ERROR"
 * @param {ArcData | string | Error } data data to be recorded
 */
export function error(data) {
  preArc("ERROR", data);
}

/**
 * Generate a arc entry and send it to Salesforce
 * defaults to logLevel of "WARN"
 * @param {ArcData | string | Error } data data to be recorded
 */
export function warn(data) {
  preArc("WARN", data);
}

/**
 * Generate a arc entry and send it to Salesforce
 * defaults to logLevel of "INFO"
 * @param {ArcData | string | Error } data data to be recorded
 */
export function info(data) {
  preArc("INFO", data);
}

/**
 * Generate a arc entry and send it to Salesforce
 * defaults to logLevel of "DEBUG"
 * @param {ArcData | string | Error } data data to be recorded
 */
export function debug(data) {
  preArc("DEBUG", data);
}

function preArc(logLevel, data) {
  // data is actually just a raw error, wrap it up
  if (data instanceof Error || (data.stack && data.message)) {
    data = { error: data };
  }
  // data is actually just a raw string, wrap it up
  if (typeof data === "string") {
    data = { message: data };
  }
  // pass down to actual arc handler
  arc({ logLevel, ...data });
}

let timeoutId = 0;
let arcs = [];

function arc(data) {
  // add log to the queue
  arcs.push(buildArc(data));
  // build all the automatic detected properties

  // ensure the timeout for committing logs is cleared
  if (timeoutId > 0) {
    clearTimeout(timeoutId);
    timeoutId = 0;
  }

  // TODO: if oldest arc is too old, commit immediately
  // TODO: if volume of the arcs is too big then commit in chunks immediately

  // Start a timer to commit arcs, this is so we can safely queue up a bunch of arcs
  // and have them go down to the server in chunks instead of per-recording action
  // eslint-disable-next-line @lwc/lwc/no-async-operation
  timeoutId = setTimeout(function commitArcEventually() {
    // TODO: commit in batches up to x size
    const arcsData = arcs;
    arcs = [];
    // take all "arcs" and send to server, clear arcs
    commitArcs({ arcsData });
  }, 2000);
}

function buildArc(data) {
  // assign default values
  let newData = { ...defaultData, ...data };
  if (!newData.details) {
    newData.details = {};
  }
  newData.details._url = window.location.href;

  // Aura doesn't deserialize generic objects well
  newData.details = JSON.stringify(newData.details);

  // process Error
  if (newData.error) {
    newData.exceptionType = "JavascriptError";
    newData.exceptionMessage = newData.error.message;
    newData.exceptionLineNumber = undefined; // TODO: need to learn to pull this from the stack
    newData.exceptionStack = newData.error.stack;
    newData.error = undefined;
  }

  // fill out location data such as stack trace
  newData = populateLocation(newData);
  return newData;
}

function populateLocation(data) {
  if (data.methodName || data.className || data.lineNum || data.stackTrace) {
    // source location already populated, not manipulating
    return data;
  }
  const stack = new Error("Source Stack").stack;
  // strip down the stack trace to exclude this file and it's data
  const lines = stack
    .split("\n")
    .filter((s) => s.trim().startsWith("at"))
    .filter((s) => !s.trim().includes("arc")); // TODO: might have some false positives here
  // try and look back through the trimmed stack to find the first reference to a component
  let source = lines.find(
    (s) => s.includes("/modules/") || s.includes("/components/")
  );
  // didn't find one, taking first line
  if (!source) {
    source = lines[0];
  }
  // take apart the stack line to try and report the location details
  const r = new RegExp(
    "(?:[ .]([^ .]+) \\()?http.*\\/(?:([\\w_-]+)\\/)([^/]+\\.js).*:(\\d+):(\\d+)"
  );
  let output = r.exec(source);
  if (!output) {
    output = [null, "unknown", "unknown", "unknown", -1];
  }
  const stackData = {
    methodName: output[1],
    className: `${output[2]}.${output[3]}`,
    lineNumber: output[4]
  };
  return { stackTrace: lines.join("\n"), ...stackData, ...data };
}
