import {
  assert,
  mockIpfsFile,
  newMockCall,
} from "matchstick-as/assembly/index";
import { newMockEvent } from "matchstick-as";
import { ethereum, BigInt, Bytes, Address } from "@graphprotocol/graph-ts";
import {
  AgreementCreated,
  AgreementJoined,
  AgreementPositionUpdated,
  AgreementFinalized,
  AgreementDisputed,
  SetUpCall,
} from "../generated/CollateralAgreementFramework/CollateralAgreementFramework";

export function createAgreementCreatedEvent(
  id: Bytes,
  termsHash: Bytes,
  criteria: BigInt,
  metadataURI: string,
  token: Address
): AgreementCreated {
  let agreementCreatedEvent = changetype<AgreementCreated>(newMockEvent());
  mockIpfsFile(metadataURI, "tests/ipfs/metadata.json");

  agreementCreatedEvent.parameters = new Array();

  agreementCreatedEvent.parameters.push(
    new ethereum.EventParam("id", ethereum.Value.fromFixedBytes(id))
  );
  agreementCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "termsHash",
      ethereum.Value.fromFixedBytes(termsHash)
    )
  );
  agreementCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "criteria",
      ethereum.Value.fromUnsignedBigInt(criteria)
    )
  );
  agreementCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "metadataURI",
      ethereum.Value.fromString(metadataURI)
    )
  );
  agreementCreatedEvent.parameters.push(
    new ethereum.EventParam("token", ethereum.Value.fromAddress(token))
  );

  return agreementCreatedEvent;
}

export function createAgreementFinalizedEvent(id: Bytes): AgreementFinalized {
  let agreementFinalizedEvent = changetype<AgreementFinalized>(newMockEvent());

  agreementFinalizedEvent.parameters = new Array();

  agreementFinalizedEvent.parameters.push(
    new ethereum.EventParam("id", ethereum.Value.fromFixedBytes(id))
  );

  return agreementFinalizedEvent;
}

export function createAgreementJoinedEvent(
  id: Bytes,
  party: Address,
  balance: BigInt
): AgreementJoined {
  let agreementJoinedEvent = changetype<AgreementJoined>(newMockEvent());

  agreementJoinedEvent.parameters = new Array();

  agreementJoinedEvent.parameters.push(
    new ethereum.EventParam("id", ethereum.Value.fromFixedBytes(id))
  );
  agreementJoinedEvent.parameters.push(
    new ethereum.EventParam("party", ethereum.Value.fromAddress(party))
  );
  agreementJoinedEvent.parameters.push(
    new ethereum.EventParam(
      "balance",
      ethereum.Value.fromUnsignedBigInt(balance)
    )
  );

  return agreementJoinedEvent;
}

export function createAgreementDisputedEvent(
  id: Bytes,
  party: Address
): AgreementDisputed {
  let agreementDisputedEvent = changetype<AgreementDisputed>(newMockEvent());

  agreementDisputedEvent.parameters = new Array();

  agreementDisputedEvent.parameters.push(
    new ethereum.EventParam("id", ethereum.Value.fromFixedBytes(id))
  );
  agreementDisputedEvent.parameters.push(
    new ethereum.EventParam("party", ethereum.Value.fromAddress(party))
  );

  return agreementDisputedEvent;
}

export function createAgreementPositionUpdatedEvent(
  id: Bytes,
  party: Address,
  balance: BigInt,
  status: BigInt
): AgreementPositionUpdated {
  let agreementPositionUpdatedEvent = changetype<AgreementPositionUpdated>(
    newMockEvent()
  );

  agreementPositionUpdatedEvent.parameters = new Array();

  agreementPositionUpdatedEvent.parameters.push(
    new ethereum.EventParam("id", ethereum.Value.fromFixedBytes(id))
  );
  agreementPositionUpdatedEvent.parameters.push(
    new ethereum.EventParam("party", ethereum.Value.fromAddress(party))
  );
  agreementPositionUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "balance",
      ethereum.Value.fromUnsignedBigInt(balance)
    )
  );
  agreementPositionUpdatedEvent.parameters.push(
    new ethereum.EventParam("status", ethereum.Value.fromUnsignedBigInt(status))
  );

  return agreementPositionUpdatedEvent;
}

export function createSetUpCall(
  framework: Address,
  arbitrator: Address,
  token: Address,
  requiredDeposit: BigInt
): SetUpCall {
  let setUpCall = changetype<SetUpCall>(newMockCall());

  let depositConfigTuple = new ethereum.Tuple();
  depositConfigTuple.push(ethereum.Value.fromAddress(token));
  depositConfigTuple.push(ethereum.Value.fromUnsignedBigInt(requiredDeposit));
  depositConfigTuple.push(ethereum.Value.fromAddress(arbitrator));

  setUpCall.inputValues = new Array();
  setUpCall.inputValues.push(
    new ethereum.EventParam(
      "arbitrator_",
      ethereum.Value.fromAddress(arbitrator)
    )
  );
  setUpCall.inputValues.push(
    new ethereum.EventParam(
      "deposits_",
      ethereum.Value.fromTuple(depositConfigTuple)
    )
  );
  setUpCall.to = framework;

  return setUpCall;
}

export function assertAgreement(
  id: string,
  termsHash: string,
  criteria: string,
  status: string,
  metadataURI: string,
  title: string
): void {
  assert.fieldEquals("Agreement", id, "status", status);
  assert.fieldEquals("Agreement", id, "termsHash", termsHash);
  assert.fieldEquals("Agreement", id, "criteria", criteria);
  assert.fieldEquals("Agreement", id, "metadataURI", metadataURI);
  assert.fieldEquals("Agreement", id, "title", title);
}

export function assertAgreementPosition(
  id: string,
  party: string,
  collateral: string,
  status: string,
  agreement: string
): void {
  assert.fieldEquals("AgreementPosition", id, "party", party);
  assert.fieldEquals("AgreementPosition", id, "collateral", collateral);
  assert.fieldEquals("AgreementPosition", id, "status", status);
  assert.fieldEquals("AgreementPosition", id, "agreement", agreement);
}
