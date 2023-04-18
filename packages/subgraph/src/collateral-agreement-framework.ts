import {
  ipfs,
  json,
  JSONValue,
  Address,
  BigInt,
  TypedMap,
} from "@graphprotocol/graph-ts";
import {
  SetUpCall,
  AgreementCreated,
  AgreementFinalized,
  AgreementJoined,
  AgreementPositionUpdated,
  AgreementDisputed,
} from "../generated/CollateralAgreementFramework/CollateralAgreementFramework";
import {
  AgreementFramework,
  Agreement,
  AgreementPosition,
  Dispute,
} from "../generated/schema";

function createAgreementPosition(
  agreementId: string,
  party: Address,
  requiredCollateral: BigInt,
  collateral: BigInt,
  deposit: BigInt,
  status: string
): void {
  let position = new AgreementPosition(agreementId.concat(party.toHexString()));
  position.party = party;
  position.requiredCollateral = requiredCollateral;
  position.collateral = collateral;
  position.deposit = deposit;
  position.status = status;
  position.agreement = agreementId;
  position.save();
}

function createAgreementPositionFromResolver(
  agreementId: string,
  key: string,
  resolver: TypedMap<string, JSONValue>
): void {
  let party = Address.fromString(key);
  let requiredCollateral = BigInt.fromString(
    resolver.get("balance") !== null
      ? (resolver.get("balance") as JSONValue).toString()
      : "0"
  );
  createAgreementPosition(
    agreementId,
    party,
    requiredCollateral,
    BigInt.zero(),
    BigInt.zero(),
    "Pending"
  );
}

export function handleAgreementCreated(event: AgreementCreated): void {
  let metadata: TypedMap<string, JSONValue> = new TypedMap();
  let file = ipfs.cat(event.params.metadataURI.replace("ipfs://", ""));
  if (file !== null) {
    metadata = json.fromBytes(file).toObject();
  }

  let framework = AgreementFramework.load(event.address.toHexString());
  if (framework === null) {
    framework = new AgreementFramework(event.address.toHexString());
  }

  let agreement = new Agreement(event.params.id.toHexString());
  agreement.framework = framework.id;
  agreement.termsHash = event.params.termsHash;
  agreement.criteria = event.params.criteria;
  agreement.status = "Created";
  agreement.metadataURI = event.params.metadataURI;
  agreement.title =
    metadata.get("title") !== null
      ? (metadata.get("title") as JSONValue).toString()
      : "Agreement";
  agreement.token = event.params.token;
  agreement.createdAt = event.block.timestamp;
  agreement.save();

  // Add pending positions from metadata
  if (metadata.get("resolvers") !== null) {
    let resolvers = (metadata.get("resolvers") as JSONValue).toObject();
    // NOTE: AssemblyScript doesn't support closures, so we need to use a for loop
    for (let i = 0; i < resolvers.entries.length; i++) {
      let entry = resolvers.entries[i];
      createAgreementPositionFromResolver(
        event.params.id.toHexString(),
        entry.key,
        entry.value.toObject()
      );
    }
  }
}

export function handleAgreementFinalized(event: AgreementFinalized): void {
  let agreement = Agreement.load(event.params.id.toHexString());
  if (agreement) {
    agreement.status = "Finalized";
    agreement.save();
  }
}

export function handleAgreementJoined(event: AgreementJoined): void {
  let framework = AgreementFramework.load(event.address.toHexString());
  let agreement = Agreement.load(event.params.id.toHexString());
  let position = AgreementPosition.load(
    event.params.id.toHexString().concat(event.params.party.toHexString())
  );

  let requiredDeposit =
    framework !== null ? framework.requiredDeposit : BigInt.zero();

  if (position !== null) {
    position.deposit = requiredDeposit;
    position.collateral = event.params.balance;
    position.status = "Joined";
    position.save();
  } else {
    createAgreementPosition(
      event.params.id.toHexString(),
      event.params.party,
      event.params.balance,
      event.params.balance,
      requiredDeposit,
      "Joined"
    );
  }

  if (agreement && agreement.status == "Created") {
    agreement.status = "Ongoing";
    agreement.save();
  }
}

export function handleAgreementPositionUpdated(
  event: AgreementPositionUpdated
): void {
  // let agreement = Agreement.load(event.params.id.toHexString());
  let position = AgreementPosition.load(
    event.params.id.toHexString().concat(event.params.party.toHexString())
  );
  if (position !== null) {
    position.collateral = event.params.balance;
    if (event.params.status == 2) position.status = "Finalized";
    else if (event.params.status == 3) {
      position.deposit = BigInt.zero();
      position.status = "Withdrawn";
    } else if (event.params.status == 4) {
      position.deposit = BigInt.zero();
      position.status = "Disputed";
    } else position.status = "Joined";
    position.save();
  }
}

export function handleAgreementDisputed(event: AgreementDisputed): void {
  let id = event.params.id.toHexString();
  let dispute = Dispute.load(id);
  let agreement = Agreement.load(id);

  if (dispute == null) {
    dispute = new Dispute(id);
    dispute.createdAt = event.block.timestamp;
  }

  if (agreement) {
    dispute.agreement = agreement.id;
    agreement.status = "Disputed";
    agreement.save();
  }

  dispute.save();
}

export function handleFrameworkSetup(call: SetUpCall): void {
  let id = call.to.toHexString();
  let framework = AgreementFramework.load(id);
  if (framework == null) {
    framework = new AgreementFramework(id);
  }
  framework.arbitrator = call.inputs.arbitrator_;
  framework.requiredDeposit = call.inputs.deposits_.amount;
  framework.save();
}
