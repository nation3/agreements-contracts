import { newMockEvent } from "matchstick-as";
import { ethereum, Bytes, Address } from "@graphprotocol/graph-ts";
import {
  ResolutionAppealed,
  ResolutionEndorsed,
  ResolutionExecuted,
  ResolutionSubmitted,
} from "../generated/Arbitrator/Arbitrator";

export function createResolutionAppealedEvent(
  resolution: Bytes,
  settlement: Bytes,
  account: Address
): ResolutionAppealed {
  let resolutionAppealedEvent = changetype<ResolutionAppealed>(newMockEvent());

  resolutionAppealedEvent.parameters = new Array();

  resolutionAppealedEvent.parameters.push(
    new ethereum.EventParam(
      "resolution",
      ethereum.Value.fromFixedBytes(resolution)
    )
  );
  resolutionAppealedEvent.parameters.push(
    new ethereum.EventParam(
      "settlement",
      ethereum.Value.fromFixedBytes(settlement)
    )
  );
  resolutionAppealedEvent.parameters.push(
    new ethereum.EventParam("account", ethereum.Value.fromAddress(account))
  );

  return resolutionAppealedEvent;
}

export function createResolutionEndorsedEvent(
  resolution: Bytes,
  settlement: Bytes
): ResolutionEndorsed {
  let resolutionEndorsedEvent = changetype<ResolutionEndorsed>(newMockEvent());

  resolutionEndorsedEvent.parameters = new Array();

  resolutionEndorsedEvent.parameters.push(
    new ethereum.EventParam(
      "resolution",
      ethereum.Value.fromFixedBytes(resolution)
    )
  );
  resolutionEndorsedEvent.parameters.push(
    new ethereum.EventParam(
      "settlement",
      ethereum.Value.fromFixedBytes(settlement)
    )
  );

  return resolutionEndorsedEvent;
}

export function createResolutionExecutedEvent(
  resolution: Bytes,
  settlement: Bytes
): ResolutionExecuted {
  let resolutionExecutedEvent = changetype<ResolutionExecuted>(newMockEvent());

  resolutionExecutedEvent.parameters = new Array();

  resolutionExecutedEvent.parameters.push(
    new ethereum.EventParam(
      "resolution",
      ethereum.Value.fromFixedBytes(resolution)
    )
  );
  resolutionExecutedEvent.parameters.push(
    new ethereum.EventParam(
      "settlement",
      ethereum.Value.fromFixedBytes(settlement)
    )
  );

  return resolutionExecutedEvent;
}

export function createResolutionSubmittedEvent(
  framework: Address,
  dispute: Bytes,
  resolution: Bytes,
  settlement: Bytes
): ResolutionSubmitted {
  let resolutionSubmittedEvent = changetype<ResolutionSubmitted>(
    newMockEvent()
  );

  resolutionSubmittedEvent.parameters = new Array();

  resolutionSubmittedEvent.parameters.push(
    new ethereum.EventParam("framework", ethereum.Value.fromAddress(framework))
  );
  resolutionSubmittedEvent.parameters.push(
    new ethereum.EventParam("dispute", ethereum.Value.fromFixedBytes(dispute))
  );
  resolutionSubmittedEvent.parameters.push(
    new ethereum.EventParam(
      "resolution",
      ethereum.Value.fromFixedBytes(resolution)
    )
  );
  resolutionSubmittedEvent.parameters.push(
    new ethereum.EventParam(
      "settlement",
      ethereum.Value.fromFixedBytes(settlement)
    )
  );

  return resolutionSubmittedEvent;
}
