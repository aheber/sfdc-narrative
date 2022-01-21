import { LightningElement } from "lwc";
import successWithLogging from "@salesforce/apex/NarrativeDemoController.successWithLogging";
import failureWithLogging from "@salesforce/apex/NarrativeDemoController.failureWithLogging";
import successWithFailingQueueable from "@salesforce/apex/NarrativeDemoController.successWithFailingQueueable";
import * as Arc from "c/arc";

export default class NarrativeDemo extends LightningElement {
  callWithSuccessApex() {
    this.takeAction(successWithLogging);
  }
  callWithFailureApex() {
    this.takeAction(failureWithLogging);
  }
  callWithQueueableFailure() {
    this.takeAction(successWithFailingQueueable);
  }
  callWithSuccessLWC() {
    this.takeAction(this.logSuccess);
  }
  callWithFailureLWC() {
    this.takeAction(this.logFailure);
  }

  takeAction(action) {
    // get message
    const message = this.template.querySelector("input").value;
    // execute action and attach logger as catch
    action
      .call(this, { message })
      .then(() => {
        console.log("success:", message);
      })
      .catch((error) => {
        console.error("failure:", error);
      });
  }

  async logSuccess(message) {
    Arc.info(message);
  }

  async logFailure(message) {
    Arc.error(new Error(message));
  }
}
