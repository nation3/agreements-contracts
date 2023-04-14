import {
  assert,
  describe,
  test,
  clearStore,
  afterEach,
  beforeEach,
} from "matchstick-as/assembly/index";
import { BigInt, Bytes, Address } from "@graphprotocol/graph-ts";
import {
  handleAgreementCreated,
  handleAgreementJoined,
  handleAgreementPositionUpdated,
  handleAgreementFinalized,
  handleAgreementDisputed,
} from "../src/agreement-framework";
import {
  createAgreementCreatedEvent,
  createAgreementDisputedEvent,
  createAgreementJoinedEvent,
  createAgreementPositionUpdatedEvent,
  createAgreementFinalizedEvent,
  assertAgreement,
  assertAgreementPosition,
} from "./agreement-framework-utils";

const ADDRESS_SAMPLE_1 = "0x89205a3a3b2a69de6dbf7f01ed13b2108b2c43e7";
const ADDRESS_SAMPLE_2 = "0x89205a3a3b2a69de6dbf7f01ed13b2108b2c43e8";
const TOKEN_SAMPLE = "0x3333333333333333333333333333333333333333";

const AGREEMENT_CREATED_EVENT_SAMPLE_1 = createAgreementCreatedEvent(
  Bytes.fromI32(200),
  Bytes.fromI32(1234567890),
  BigInt.fromI32(1000),
  "Metadata",
  Address.fromString(TOKEN_SAMPLE)
);

const AGREEMENT_CREATED_EVENT_SAMPLE_2 = createAgreementCreatedEvent(
  Bytes.fromI32(201),
  Bytes.fromI32(1234567890),
  BigInt.fromI32(1100),
  "Metadata",
  Address.fromString(TOKEN_SAMPLE)
);

const AGREEMENT_JOINED_EVENT_SAMPLE_1 = createAgreementJoinedEvent(
  Bytes.fromI32(200),
  Address.fromString(ADDRESS_SAMPLE_1),
  BigInt.fromI32(1050)
);

const AGREEMENT_JOINED_EVENT_SAMPLE_2 = createAgreementJoinedEvent(
  Bytes.fromI32(200),
  Address.fromString(ADDRESS_SAMPLE_2),
  BigInt.fromI32(1090)
);

const AGREEMENT_JOINED_EVENT_SAMPLE_3 = createAgreementJoinedEvent(
  Bytes.fromI32(201),
  Address.fromString(ADDRESS_SAMPLE_1),
  BigInt.fromI32(1190)
);

const AGREEMENT_JOINED_EVENT_SAMPLE_4 = createAgreementJoinedEvent(
  Bytes.fromI32(201),
  Address.fromString(ADDRESS_SAMPLE_2),
  BigInt.fromI32(1290)
);

const AGREEMENT_POSITION_JOINED_EVENT_1 = createAgreementPositionUpdatedEvent(
  Bytes.fromI32(200),
  Address.fromString(ADDRESS_SAMPLE_1),
  BigInt.fromI32(1050),
  BigInt.fromI32(1)
);

const AGREEMENT_POSITION_JOINED_EVENT_2 = createAgreementPositionUpdatedEvent(
  Bytes.fromI32(200),
  Address.fromString(ADDRESS_SAMPLE_2),
  BigInt.fromI32(1090),
  BigInt.fromI32(1)
);

const AGREEMENT_POSITION_UPDATED_EVENT_1 = createAgreementPositionUpdatedEvent(
  Bytes.fromI32(200),
  Address.fromString(ADDRESS_SAMPLE_1),
  BigInt.fromI32(5000),
  BigInt.fromI32(1)
);

const AGREEMENT_POSITION_FINALIZED_EVENT_1 =
  createAgreementPositionUpdatedEvent(
    Bytes.fromI32(200),
    Address.fromString(ADDRESS_SAMPLE_1),
    BigInt.fromI32(1050),
    BigInt.fromI32(2)
  );

const AGREEMENT_POSITION_FINALIZED_EVENT_2 =
  createAgreementPositionUpdatedEvent(
    Bytes.fromI32(200),
    Address.fromString(ADDRESS_SAMPLE_2),
    BigInt.fromI32(1090),
    BigInt.fromI32(2)
  );

const AGREEMENT_POSITION_WITHDRAWN_EVENT_1 =
  createAgreementPositionUpdatedEvent(
    Bytes.fromI32(200),
    Address.fromString(ADDRESS_SAMPLE_1),
    BigInt.fromI32(1050),
    BigInt.fromI32(3)
  );

const AGREEMENT_POSITION_DISPUTED_EVENT_1 = createAgreementPositionUpdatedEvent(
  Bytes.fromI32(200),
  Address.fromString(ADDRESS_SAMPLE_1),
  BigInt.fromI32(1050),
  BigInt.fromI32(4)
);

const AGREEMENT_FINALIZED_EVENT_SAMPLE_1 = createAgreementFinalizedEvent(
  Bytes.fromI32(200)
);

const AGREEMENT_DISPUTED_EVENT_SAMPLE_1 = createAgreementDisputedEvent(
  Bytes.fromI32(200),
  Address.fromString(ADDRESS_SAMPLE_1)
);

describe("handling of AgreementCreated", () => {
  afterEach(() => {
    clearStore();
  });

  test("one agreement created", () => {
    const created = AGREEMENT_CREATED_EVENT_SAMPLE_1.params;
    const willJoin = AGREEMENT_JOINED_EVENT_SAMPLE_1.params;
    const willJoin2 = AGREEMENT_JOINED_EVENT_SAMPLE_2.params;

    handleAgreementCreated(AGREEMENT_CREATED_EVENT_SAMPLE_1);

    // assert that the agreement was created
    assert.entityCount("Agreement", 1);

    assertAgreement(
      created.id.toHexString(),
      created.termsHash.toHexString(),
      created.criteria.toString(),
      "Created",
      created.metadataURI.toString(),
      "Agreement Test"
    );

    // assert that the agreement pending positions were created
    assert.entityCount("AgreementPosition", 2);

    assertAgreementPosition(
      created.id.toHexString().concat(willJoin.party.toHexString()),
      willJoin.party.toHexString(),
      "0",
      "Pending",
      created.id.toHexString()
    );
    assertAgreementPosition(
      created.id.toHexString().concat(willJoin2.party.toHexString()),
      willJoin2.party.toHexString(),
      "0",
      "Pending",
      created.id.toHexString()
    );
  });

  test("two agreement created", () => {
    const created = AGREEMENT_CREATED_EVENT_SAMPLE_1.params;
    const created2 = AGREEMENT_CREATED_EVENT_SAMPLE_2.params;

    handleAgreementCreated(AGREEMENT_CREATED_EVENT_SAMPLE_1);
    handleAgreementCreated(AGREEMENT_CREATED_EVENT_SAMPLE_2);

    assert.entityCount("Agreement", 2);

    assertAgreement(
      created.id.toHexString(),
      created.termsHash.toHexString(),
      created.criteria.toString(),
      "Created",
      created.metadataURI.toString(),
      "Agreement Test"
    );

    assertAgreement(
      created2.id.toHexString(),
      created2.termsHash.toHexString(),
      created2.criteria.toString(),
      "Created",
      created2.metadataURI.toString(),
      "Agreement Test"
    );
  });
});

describe("handling of AgreementJoined", () => {
  describe("one agreement created", () => {
    afterEach(() => {
      clearStore();
    });

    beforeEach(() => {
      handleAgreementCreated(AGREEMENT_CREATED_EVENT_SAMPLE_1);
    });

    test("agreement joined once", () => {
      let created = AGREEMENT_CREATED_EVENT_SAMPLE_1.params;
      let joined = AGREEMENT_JOINED_EVENT_SAMPLE_1.params;
      let positionId = joined.id
        .toHexString()
        .concat(joined.party.toHexString());

      handleAgreementJoined(AGREEMENT_JOINED_EVENT_SAMPLE_1);

      assert.entityCount("Agreement", 1);
      assert.entityCount("AgreementPosition", 2);

      assert.fieldEquals(
        "Agreement",
        created.id.toHexString(),
        "status",
        "Ongoing"
      );

      assertAgreementPosition(
        positionId,
        joined.party.toHexString(),
        joined.balance.toString(),
        "Joined",
        joined.id.toHexString()
      );
    });

    test("agreement joined twice", () => {
      let created = AGREEMENT_CREATED_EVENT_SAMPLE_1.params;
      let joined = AGREEMENT_JOINED_EVENT_SAMPLE_1.params;
      let joined2 = AGREEMENT_JOINED_EVENT_SAMPLE_2.params;
      let positionId = joined.id
        .toHexString()
        .concat(joined.party.toHexString());
      let position2Id = joined2.id
        .toHexString()
        .concat(joined2.party.toHexString());

      handleAgreementJoined(AGREEMENT_JOINED_EVENT_SAMPLE_1);
      handleAgreementJoined(AGREEMENT_JOINED_EVENT_SAMPLE_2);

      assert.entityCount("Agreement", 1);
      assert.entityCount("AgreementPosition", 2);

      assert.fieldEquals(
        "Agreement",
        created.id.toHexString(),
        "status",
        "Ongoing"
      );
      assertAgreementPosition(
        positionId,
        joined.party.toHexString(),
        joined.balance.toString(),
        "Joined",
        joined.id.toHexString()
      );
      assertAgreementPosition(
        position2Id,
        joined2.party.toHexString(),
        joined2.balance.toString(),
        "Joined",
        joined2.id.toHexString()
      );
    });
  });

  describe("two agreemeents created", () => {
    afterEach(() => {
      clearStore();
    });

    beforeEach(() => {
      handleAgreementCreated(AGREEMENT_CREATED_EVENT_SAMPLE_1);
      handleAgreementCreated(AGREEMENT_CREATED_EVENT_SAMPLE_2);
    });

    test("each agreement joined once", () => {
      let created = AGREEMENT_CREATED_EVENT_SAMPLE_1.params;
      let created2 = AGREEMENT_CREATED_EVENT_SAMPLE_2.params;
      let joined = AGREEMENT_JOINED_EVENT_SAMPLE_1.params;
      let joined2 = AGREEMENT_JOINED_EVENT_SAMPLE_3.params;
      let positionId = joined.id
        .toHexString()
        .concat(joined.party.toHexString());
      let position2Id = joined2.id
        .toHexString()
        .concat(joined2.party.toHexString());

      handleAgreementJoined(AGREEMENT_JOINED_EVENT_SAMPLE_1);
      handleAgreementJoined(AGREEMENT_JOINED_EVENT_SAMPLE_3);

      assert.entityCount("Agreement", 2);
      assert.entityCount("AgreementPosition", 4);

      assert.fieldEquals(
        "Agreement",
        created.id.toHexString(),
        "status",
        "Ongoing"
      );
      assert.fieldEquals(
        "Agreement",
        created2.id.toHexString(),
        "status",
        "Ongoing"
      );

      assertAgreementPosition(
        positionId,
        joined.party.toHexString(),
        joined.balance.toString(),
        "Joined",
        joined.id.toHexString()
      );
      assertAgreementPosition(
        position2Id,
        joined2.party.toHexString(),
        joined2.balance.toString(),
        "Joined",
        joined2.id.toHexString()
      );
    });

    test("each agreement joined twice", () => {
      let joined = AGREEMENT_JOINED_EVENT_SAMPLE_1.params;
      let joined2 = AGREEMENT_JOINED_EVENT_SAMPLE_2.params;
      let joined3 = AGREEMENT_JOINED_EVENT_SAMPLE_3.params;
      let joined4 = AGREEMENT_JOINED_EVENT_SAMPLE_4.params;

      handleAgreementJoined(AGREEMENT_JOINED_EVENT_SAMPLE_1);
      handleAgreementJoined(AGREEMENT_JOINED_EVENT_SAMPLE_2);
      handleAgreementJoined(AGREEMENT_JOINED_EVENT_SAMPLE_3);
      handleAgreementJoined(AGREEMENT_JOINED_EVENT_SAMPLE_4);

      assert.entityCount("Agreement", 2);
      assert.entityCount("AgreementPosition", 4);

      assertAgreementPosition(
        joined.id.toHexString().concat(joined.party.toHexString()),
        joined.party.toHexString(),
        joined.balance.toString(),
        "Joined",
        joined.id.toHexString()
      );
      assertAgreementPosition(
        joined2.id.toHexString().concat(joined2.party.toHexString()),
        joined2.party.toHexString(),
        joined2.balance.toString(),
        "Joined",
        joined2.id.toHexString()
      );
      assertAgreementPosition(
        joined3.id.toHexString().concat(joined3.party.toHexString()),
        joined3.party.toHexString(),
        joined3.balance.toString(),
        "Joined",
        joined3.id.toHexString()
      );
      assertAgreementPosition(
        joined4.id.toHexString().concat(joined4.party.toHexString()),
        joined4.party.toHexString(),
        joined4.balance.toString(),
        "Joined",
        joined4.id.toHexString()
      );
    });
  });
});

describe("handling of AgreementPositionUpdated", () => {
  afterEach(() => {
    clearStore();
  });

  beforeEach(() => {
    handleAgreementCreated(AGREEMENT_CREATED_EVENT_SAMPLE_1);
    handleAgreementJoined(AGREEMENT_JOINED_EVENT_SAMPLE_1);
  });

  test("position balance changes", () => {
    let updated = AGREEMENT_POSITION_UPDATED_EVENT_1.params;

    handleAgreementPositionUpdated(AGREEMENT_POSITION_UPDATED_EVENT_1);

    assert.entityCount("Agreement", 1);
    assert.entityCount("AgreementPosition", 2);

    assertAgreementPosition(
      updated.id.toHexString().concat(updated.party.toHexString()),
      updated.party.toHexString(),
      updated.balance.toString(),
      "Joined",
      updated.id.toHexString()
    );
  });

  test("position finalized", () => {
    let updated = AGREEMENT_POSITION_FINALIZED_EVENT_1.params;

    handleAgreementPositionUpdated(AGREEMENT_POSITION_FINALIZED_EVENT_1);

    assert.entityCount("Agreement", 1);
    assert.entityCount("AgreementPosition", 2);

    assertAgreementPosition(
      updated.id.toHexString().concat(updated.party.toHexString()),
      updated.party.toHexString(),
      updated.balance.toString(),
      "Finalized",
      updated.id.toHexString()
    );
  });

  test("position disputed", () => {
    let updated = AGREEMENT_POSITION_DISPUTED_EVENT_1.params;

    handleAgreementPositionUpdated(AGREEMENT_POSITION_DISPUTED_EVENT_1);

    assert.entityCount("Agreement", 1);
    assert.entityCount("AgreementPosition", 2);

    assertAgreementPosition(
      updated.id.toHexString().concat(updated.party.toHexString()),
      updated.party.toHexString(),
      updated.balance.toString(),
      "Disputed",
      updated.id.toHexString()
    );
  });

  test("position withdraws", () => {
    let updated = AGREEMENT_POSITION_WITHDRAWN_EVENT_1.params;

    handleAgreementPositionUpdated(AGREEMENT_POSITION_WITHDRAWN_EVENT_1);

    assert.entityCount("Agreement", 1);
    assert.entityCount("AgreementPosition", 2);

    assertAgreementPosition(
      updated.id.toHexString().concat(updated.party.toHexString()),
      updated.party.toHexString(),
      updated.balance.toString(),
      "Withdrawn",
      updated.id.toHexString()
    );
  });
});

describe("handling of AgreementFinalized", () => {
  afterEach(() => {
    clearStore();
  });

  beforeEach(() => {
    handleAgreementCreated(AGREEMENT_CREATED_EVENT_SAMPLE_1);
    handleAgreementJoined(AGREEMENT_JOINED_EVENT_SAMPLE_1);
    handleAgreementJoined(AGREEMENT_JOINED_EVENT_SAMPLE_2);
    handleAgreementPositionUpdated(AGREEMENT_POSITION_JOINED_EVENT_1);
    handleAgreementPositionUpdated(AGREEMENT_POSITION_JOINED_EVENT_2);
  });

  test("one agremeent finalized", () => {
    let created = AGREEMENT_CREATED_EVENT_SAMPLE_1.params;
    let finalized = AGREEMENT_POSITION_FINALIZED_EVENT_1.params;
    let finalized2 = AGREEMENT_POSITION_FINALIZED_EVENT_2.params;

    handleAgreementPositionUpdated(AGREEMENT_POSITION_FINALIZED_EVENT_1);
    handleAgreementPositionUpdated(AGREEMENT_POSITION_FINALIZED_EVENT_2);
    handleAgreementFinalized(AGREEMENT_FINALIZED_EVENT_SAMPLE_1);

    assert.entityCount("Agreement", 1);
    assert.entityCount("AgreementPosition", 2);

    assert.fieldEquals(
      "Agreement",
      created.id.toHexString(),
      "status",
      "Finalized"
    );
    assertAgreementPosition(
      finalized.id.toHexString().concat(finalized.party.toHexString()),
      finalized.party.toHexString(),
      finalized.balance.toString(),
      "Finalized",
      finalized.id.toHexString()
    );
    assertAgreementPosition(
      finalized2.id.toHexString().concat(finalized2.party.toHexString()),
      finalized2.party.toHexString(),
      finalized2.balance.toString(),
      "Finalized",
      finalized2.id.toHexString()
    );
  });
});

describe("handling of AgreementDisputed", () => {
  afterEach(() => {
    clearStore();
  });

  beforeEach(() => {
    handleAgreementCreated(AGREEMENT_CREATED_EVENT_SAMPLE_1);
    handleAgreementJoined(AGREEMENT_JOINED_EVENT_SAMPLE_1);
    handleAgreementJoined(AGREEMENT_JOINED_EVENT_SAMPLE_2);
  });

  test("one agreement disputed", () => {
    let created = AGREEMENT_CREATED_EVENT_SAMPLE_1.params;
    let joined = AGREEMENT_JOINED_EVENT_SAMPLE_1.params;
    let joined2 = AGREEMENT_JOINED_EVENT_SAMPLE_2.params;

    assert.fieldEquals(
      "Agreement",
      created.id.toHexString(),
      "status",
      "Ongoing"
    );

    handleAgreementPositionUpdated(AGREEMENT_POSITION_DISPUTED_EVENT_1);
    handleAgreementDisputed(AGREEMENT_DISPUTED_EVENT_SAMPLE_1);

    assert.entityCount("Agreement", 1);
    assert.entityCount("AgreementPosition", 2);
    assert.entityCount("Dispute", 1);

    assert.fieldEquals(
      "Agreement",
      created.id.toHexString(),
      "status",
      "Disputed"
    );

    assertAgreementPosition(
      joined.id.toHexString().concat(joined.party.toHexString()),
      joined.party.toHexString(),
      joined.balance.toString(),
      "Disputed",
      joined.id.toHexString()
    );
    assertAgreementPosition(
      joined2.id.toHexString().concat(joined2.party.toHexString()),
      joined2.party.toHexString(),
      joined2.balance.toString(),
      "Joined",
      joined2.id.toHexString()
    );

    assert.fieldEquals(
      "Dispute",
      created.id.toHexString(),
      "agreement",
      created.id.toHexString()
    );
  });
});
