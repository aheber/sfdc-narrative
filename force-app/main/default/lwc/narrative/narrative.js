import { LightningElement, track } from "lwc";
import { subscribe, unsubscribe, onError } from "lightning/empApi";

export default class Narrative extends LightningElement {
  channelName = "/event/Arc_Event__e";
  selectedEventPayload = "";
  selectedReplayId = "";
  selectedCreatedBy = "";

  @track
  selectedEventSection = [];

  @track events = [];

  isSubscribeDisabled = false;

  get isUnsubscribeDisabled() {
    return !this.isSubscribeDisabled;
  }

  subscription = {};

  // Tracks changes to channelName text field
  handleChannelName(event) {
    this.channelName = event.target.value;
  }

  // Initializes the component
  connectedCallback() {
    // Register error listener
    this.registerErrorListener();
  }
  handleRowSelect(event) {
    const replayId = parseInt(event.currentTarget.dataset.id);
    const selectedEvent = this.events.find(
      (e) => e.event.replayId === replayId
    );
    this.selectedEventPayload = selectedEvent.payload.Payload__c;
    this.selectedReplayId = selectedEvent.event.replayId;
    this.selectedCreatedBy = selectedEvent.payload.CreatedById;
    this.buildSections(this.selectedEventPayload);
  }

  buildSections(payload) {
    const p = JSON.parse(payload);
    this.selectedEventSection = Object.keys(p)
      .sort()
      .map((k) => {
        return { name: k, value: JSON.stringify(p[k], null, 2) };
      });
  }

  // Handles subscribe button click
  handleSubscribe() {
    // Callback invoked whenever a new event message is received
    const messageCallback = (response) => {
      console.log("New message received: ", JSON.stringify(response));
      // Response contains the payload of the new message received
      this.events.unshift(response.data);
    };

    // Invoke subscribe method of empApi. Pass reference to messageCallback
    subscribe(this.channelName, -1, messageCallback).then((response) => {
      // Response contains the subscription information on subscribe call
      console.log(
        "Subscription request sent to: ",
        JSON.stringify(response.channel)
      );
      this.subscription = response;
      this.toggleSubscribeButton(true);
    });
  }

  // Handles unsubscribe button click
  handleUnsubscribe() {
    this.toggleSubscribeButton(false);

    // Invoke unsubscribe method of empApi
    unsubscribe(this.subscription, (response) => {
      console.log("unsubscribe() response: ", JSON.stringify(response));
      // Response is true for successful unsubscribe
    });
  }

  toggleSubscribeButton(enableSubscribe) {
    this.isSubscribeDisabled = enableSubscribe;
  }

  registerErrorListener() {
    // Invoke onError empApi method
    onError((error) => {
      console.log("Received error from server: ", JSON.stringify(error));
      // Error contains the server-side error
    });
  }
}
