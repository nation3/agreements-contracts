import {
  ResolutionAppealed as ResolutionAppealedEvent,
  ResolutionEndorsed as ResolutionEndorsedEvent,
  ResolutionExecuted as ResolutionExecutedEvent,
  ResolutionSubmitted as ResolutionSubmittedEvent,
} from "../generated/Arbitrator/Arbitrator";
import { Dispute, Settlement } from "../generated/schema";

export function handleResolutionAppealed(event: ResolutionAppealedEvent): void {
  let settlement = Settlement.load(event.params.settlement.toHexString());
  if (settlement) {
    settlement.status = "Appealed";
    settlement.save();
  }
}

export function handleResolutionEndorsed(event: ResolutionEndorsedEvent): void {
  let settlement = Settlement.load(event.params.settlement.toHexString());
  if (settlement) {
    settlement.status = "Endorsed";
    settlement.save();
  }
}

export function handleResolutionExecuted(event: ResolutionExecutedEvent): void {
  let settlement = Settlement.load(event.params.settlement.toHexString());
  if (settlement) {
    settlement.status = "Executed";
    settlement.save();
  }
}

export function handleResolutionSubmitted(
  event: ResolutionSubmittedEvent
): void {
  let dispute = Dispute.load(event.params.dispute.toHexString());

  let settlement = Settlement.load(event.params.settlement.toHexString());

  if (dispute != null) {
    if (settlement == null) {
      settlement = new Settlement(event.params.settlement.toHexString());
    }
    settlement.submittedAt = event.block.timestamp;
    settlement.status = "Submitted";
    settlement.dispute = dispute.id;
    settlement.save();

    if (!dispute.resolution) dispute.resolution = event.params.resolution;
    dispute.settlement = settlement.id;
    dispute.save();
  }
}
