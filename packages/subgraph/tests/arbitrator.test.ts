import { Address, BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  assert,
  describe,
  test,
  clearStore,
  afterAll,
  beforeEach,
  beforeAll,
} from "matchstick-as/assembly/index";
import {
  handleResolutionSubmitted,
  handleResolutionAppealed,
  handleResolutionEndorsed,
  handleResolutionExecuted,
} from "../src/arbitrator";
import {
  createResolutionSubmittedEvent,
  createResolutionExecutedEvent,
  createResolutionAppealedEvent,
  createResolutionEndorsedEvent,
} from "./arbitrator-utils";
import { Dispute } from "../generated/schema";

const FRAMEWORK_ADDRESS = "0x8888888888888888888888888888888888888888";
const SAMPLE_ADDRESS = "0x89205a3a3b2a69de6dbf7f01ed13b2108b2c43e7";

const RESOLUTION_SUBMITTED_EVENT = createResolutionSubmittedEvent(
  Address.fromString(FRAMEWORK_ADDRESS),
  Bytes.fromI32(314),
  Bytes.fromI32(42314),
  Bytes.fromI32(111)
);

const RESOLUTION_SUBMITTED_EVENT_2 = createResolutionSubmittedEvent(
  Address.fromString(FRAMEWORK_ADDRESS),
  Bytes.fromI32(314),
  Bytes.fromI32(42314),
  Bytes.fromI32(112)
);

describe("handling of submitResolution", () => {
  beforeAll(() => {
    let dispute = new Dispute(Bytes.fromI32(314).toHexString());
    dispute.createdAt = BigInt.fromI32(0);
    dispute.save();
  });
  afterAll(() => {
    clearStore();
  });

  test("resolution submitted", () => {
    const submitted = RESOLUTION_SUBMITTED_EVENT;

    handleResolutionSubmitted(submitted);

    assert.entityCount("Settlement", 1);

    assert.fieldEquals(
      "Settlement",
      submitted.params.settlement.toHexString(),
      "dispute",
      submitted.params.dispute.toHexString()
    );
    assert.fieldEquals(
      "Settlement",
      submitted.params.settlement.toHexString(),
      "status",
      "Submitted"
    );
    assert.fieldEquals(
      "Settlement",
      submitted.params.settlement.toHexString(),
      "submittedAt",
      submitted.block.timestamp.toString()
    );
    assert.fieldEquals(
      "Dispute",
      submitted.params.dispute.toHexString(),
      "settlement",
      submitted.params.settlement.toHexString()
    );
  });

  describe("one resolution submitted", () => {
    beforeEach(() => {
      handleResolutionSubmitted(RESOLUTION_SUBMITTED_EVENT);
    });

    test("resolution appealed", () => {
      const appealed = createResolutionAppealedEvent(
        Bytes.fromI32(42314),
        Bytes.fromI32(111),
        Address.fromString(SAMPLE_ADDRESS)
      );

      handleResolutionAppealed(appealed);

      assert.fieldEquals(
        "Settlement",
        appealed.params.settlement.toHexString(),
        "status",
        "Appealed"
      );
    });

    test("resolution endorsed", () => {
      const endorsed = createResolutionEndorsedEvent(
        Bytes.fromI32(42314),
        Bytes.fromI32(111)
      );

      handleResolutionEndorsed(endorsed);

      assert.fieldEquals(
        "Settlement",
        endorsed.params.settlement.toHexString(),
        "status",
        "Endorsed"
      );
    });

    test("resolution executed", () => {
      const executed = createResolutionExecutedEvent(
        Bytes.fromI32(42314),
        Bytes.fromI32(111)
      );

      handleResolutionExecuted(executed);

      assert.fieldEquals(
        "Settlement",
        executed.params.settlement.toHexString(),
        "status",
        "Executed"
      );
    });

    test("new resolution submitted", () => {
      const submitted_1 = RESOLUTION_SUBMITTED_EVENT;
      const submitted_2 = RESOLUTION_SUBMITTED_EVENT_2;

      assert.fieldEquals(
        "Dispute",
        submitted_1.params.dispute.toHexString(),
        "settlement",
        submitted_1.params.settlement.toHexString()
      );

      handleResolutionSubmitted(submitted_2);

      assert.entityCount("Settlement", 2);
      assert.fieldEquals(
        "Dispute",
        submitted_1.params.dispute.toHexString(),
        "settlement",
        submitted_2.params.settlement.toHexString()
      );
    });
  });
});
