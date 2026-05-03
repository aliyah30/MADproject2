import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// TYPES
// ─────────────────────────────────────────────────────────────────────────────

interface ActivityInput {
  activityId: string;
  name: string;
  location: string;
  openHours: string;
  cost: number;
  orderIndex: number;
}

interface OptimizerRequest {
  tripId: string;
  budget: number;
  activities: ActivityInput[];
}

interface OptimizerMove {
  activityId: string;
  activityName: string;
  originalIndex: number;
  newIndex: number;
  score: number;
  reason: string;
}

interface OptimizerResponse {
  optimizedActivities: Array<{activityId: string; newIndex: number}>;
  moves: OptimizerMove[];
  totalEstimatedCost: number;
  budgetStatus: "within" | "over";
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

function parseTimeToMinutes(timeStr: string): number | null {
  const clean = timeStr.trim().toUpperCase();
  const match = clean.match(/^(\d{1,2}):(\d{2})\s*(AM|PM)$/);
  if (!match) return null;

  let hours = parseInt(match[1], 10);
  const minutes = parseInt(match[2], 10);
  const period = match[3];

  if (period === "PM" && hours !== 12) hours += 12;
  if (period === "AM" && hours === 12) hours = 0;

  return hours * 60 + minutes;
}

function parseOpenHours(openHours: string): {open: number; close: number} | null {
  const parts = openHours.split(/[-–]/);
  if (parts.length < 2) return null;

  const openMin = parseTimeToMinutes(parts[0].trim());
  const closeMin = parseTimeToMinutes(parts[1].trim());

  if (openMin === null || closeMin === null) return null;
  return {open: openMin, close: closeMin};
}

function estimateTravelMinutes(fromLocation: string, toLocation: string): number {
  if (fromLocation.toLowerCase() === toLocation.toLowerCase()) return 0;

  const fromWords = new Set(fromLocation.toLowerCase().split(/[\s,]+/));
  const toWords = toLocation.toLowerCase().split(/[\s,]+/);
  const sharedWords = toWords.filter((w) => fromWords.has(w) && w.length > 3);

  if (sharedWords.length > 0) return 10;
  return 25;
}

function scoreActivity(
  activity: ActivityInput,
  prevLocation: string,
  cumulativeCost: number,
  budget: number,
  visitHour: number
): {score: number; reasons: string[]} {
  const reasons: string[] = [];
  let penalty = 0;

  // Distance penalty
  const travelMin = estimateTravelMinutes(prevLocation, activity.location);
  const distancePenalty = Math.min(40, travelMin * 1.6);
  penalty += distancePenalty;

  if (travelMin === 0) {
    reasons.push("same area as previous activity — no extra travel needed");
  } else if (travelMin <= 10) {
    reasons.push(`short ${travelMin}-min trip from previous activity`);
  } else {
    reasons.push(`${travelMin}-min travel from previous activity`);
  }

  // Opening hours penalty
  const hours = parseOpenHours(activity.openHours);
  const visitMinutes = visitHour * 60;

  if (hours !== null) {
    if (visitMinutes < hours.open) {
      const waitMin = hours.open - visitMinutes;
      penalty += Math.min(40, waitMin * 0.8);
      reasons.push(
        `arrives ${Math.round(waitMin / 60 * 10) / 10}h before opening at ` +
        `${activity.openHours.split(/[-–]/)[0].trim()}`
      );
    } else if (visitMinutes > hours.close) {
      penalty += 40;
      reasons.push(
        `already closed at this time (closes ${activity.openHours.split(/[-–]/)[1]?.trim() ?? ""})`
      );
    } else {
      reasons.push(`open at visit time (${activity.openHours})`);
    }
  }

  // Budget penalty
  const newCumulative = cumulativeCost + activity.cost;
  if (newCumulative > budget) {
    const over = newCumulative - budget;
    penalty += Math.min(20, over * 0.1);
    reasons.push(
      `adds $${activity.cost.toFixed(0)} — cumulative $${newCumulative.toFixed(0)} exceeds $${budget.toFixed(0)} budget`
    );
  } else {
    reasons.push(`$${activity.cost.toFixed(0)} fits within remaining budget`);
  }

  const score = Math.max(0, 100 - penalty);
  return {score, reasons};
}

function buildMoveReason(
  originalIndex: number,
  newIndex: number,
  scoreReasons: string[]
): string {
  if (originalIndex === newIndex) {
    return `Kept in position ${newIndex + 1} — already optimally placed. ${scoreReasons[0] ?? ""}`;
  }

  const direction = newIndex < originalIndex ? "earlier" : "later";
  const primary = scoreReasons[0] ?? "";
  const secondary = scoreReasons[1] ?? "";

  return (
    `Moved ${direction} to position ${newIndex + 1}: ${primary}` +
    (secondary ? `; ${secondary}` : "") +
    "."
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CLOUD FUNCTION: optimizeItinerary
// ─────────────────────────────────────────────────────────────────────────────

export const optimizeItinerary = functions.https.onCall(
  async (data: OptimizerRequest, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "You must be signed in to optimize an itinerary."
      );
    }

    const {tripId, budget, activities} = data;

    if (!tripId || !activities || activities.length === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "tripId and a non-empty activities array are required."
      );
    }

    const tripDoc = await db.collection("trips").doc(tripId).get();
    if (!tripDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Trip not found.");
    }

    const tripData = tripDoc.data() as {memberUids?: string[]};
    if (!tripData.memberUids?.includes(context.auth.uid)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "You are not a member of this trip."
      );
    }

    const START_HOUR = 9;
    const AVG_ACTIVITY_MINUTES = 90;

    const remaining = [...activities];
    const ordered: ActivityInput[] = [];
    const moves: OptimizerMove[] = [];

    let currentLocation = "start";
    let cumulativeCost = 0;
    let currentMinute = START_HOUR * 60;

    while (remaining.length > 0) {
      let bestScore = -1;
      let bestIdx = 0;
      let bestReasons: string[] = [];

      for (let i = 0; i < remaining.length; i++) {
        const candidate = remaining[i];
        const visitHour = Math.floor(currentMinute / 60);
        const {score, reasons} = scoreActivity(
          candidate,
          currentLocation,
          cumulativeCost,
          budget,
          visitHour
        );

        if (score > bestScore) {
          bestScore = score;
          bestIdx = i;
          bestReasons = reasons;
        }
      }

      const chosen = remaining.splice(bestIdx, 1)[0];
      const newIndex = ordered.length;
      const originalIndex = activities.findIndex(
        (a) => a.activityId === chosen.activityId
      );

      const reason = buildMoveReason(originalIndex, newIndex, bestReasons);

      moves.push({
        activityId: chosen.activityId,
        activityName: chosen.name,
        originalIndex,
        newIndex,
        score: Math.round(bestScore * 10) / 10,
        reason,
      });

      ordered.push(chosen);
      currentLocation = chosen.location;
      cumulativeCost += chosen.cost;

      const travelMin = currentLocation === "start" ?
        0 :
        estimateTravelMinutes(currentLocation, chosen.location);
      currentMinute += travelMin + AVG_ACTIVITY_MINUTES;
    }

    const totalEstimatedCost = ordered.reduce((sum, a) => sum + a.cost, 0);

    const response: OptimizerResponse = {
      optimizedActivities: ordered.map((a, i) => ({
        activityId: a.activityId,
        newIndex: i,
      })),
      moves,
      totalEstimatedCost: Math.round(totalEstimatedCost * 100) / 100,
      budgetStatus: totalEstimatedCost <= budget ? "within" : "over",
    };

    return response;
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// CLOUD FUNCTION: notifyOnItineraryChange
// ─────────────────────────────────────────────────────────────────────────────

export const notifyOnItineraryChange = functions.firestore
  .document("activities/{activityId}")
  .onWrite(async (change) => {
    const isDelete = !change.after.exists;
    const isCreate = !change.before.exists;

    const activityData = (
      change.after.exists ? change.after.data() : change.before.data()
    ) as {tripId: string; name: string} | undefined;

    if (!activityData) return;

    const {tripId, name} = activityData;

    const tripDoc = await db.collection("trips").doc(tripId).get();
    if (!tripDoc.exists) return;

    const tripData = tripDoc.data() as {name: string; memberUids: string[]};

    const body =
      isDelete ? `"${name}" was removed from the itinerary` :
      isCreate ? `"${name}" was added to the itinerary` :
      `"${name}" was updated in the itinerary`;

    const memberDocs = await Promise.all(
      tripData.memberUids.map((uid) => db.collection("users").doc(uid).get())
    );

    const tokens: string[] = [];
    for (const doc of memberDocs) {
      if (!doc.exists) continue;
      const userData = doc.data() as {fcmTokens?: string[]};
      if (userData.fcmTokens) tokens.push(...userData.fcmTokens);
    }

    if (tokens.length === 0) return;

    const message: admin.messaging.MulticastMessage = {
      notification: {title: tripData.name, body},
      data: {tripId, type: "itinerary_change"},
      tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    const staleTokens: string[] = [];
    response.responses.forEach((r, i) => {
      if (
        !r.success && (
          r.error?.code === "messaging/invalid-registration-token" ||
          r.error?.code === "messaging/registration-token-not-registered"
        )
      ) {
        staleTokens.push(tokens[i]);
      }
    });

    if (staleTokens.length > 0) {
      const batch = db.batch();
      for (const doc of memberDocs) {
        if (!doc.exists) continue;
        const userData = doc.data() as {fcmTokens?: string[]};
        const userStale = staleTokens.filter((t) => userData.fcmTokens?.includes(t));
        if (userStale.length > 0) {
          batch.update(doc.ref, {
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...userStale),
          });
        }
      }
      await batch.commit();
    }
  });

// ─────────────────────────────────────────────────────────────────────────────
// CLOUD FUNCTION: notifyOnPackingListChange
// ─────────────────────────────────────────────────────────────────────────────

export const notifyOnPackingListChange = functions.firestore
  .document("packingList/{tripId}")
  .onUpdate(async (change, context) => {
    const tripId = context.params.tripId;

    const before = change.before.data() as {items: Array<{checked: boolean; name: string}>};
    const after = change.after.data() as {items: Array<{checked: boolean; name: string}>};

    let changedItemName: string | null = null;
    let wasChecked = false;

    for (let i = 0; i < after.items.length; i++) {
      const afterItem = after.items[i];
      const beforeItem = before.items.find((b) => b.name === afterItem.name);
      if (beforeItem && beforeItem.checked !== afterItem.checked) {
        changedItemName = afterItem.name;
        wasChecked = afterItem.checked;
        break;
      }
    }

    if (!changedItemName) return;

    const tripDoc = await db.collection("trips").doc(tripId).get();
    if (!tripDoc.exists) return;

    const tripData = tripDoc.data() as {name: string; memberUids: string[]};
    const body = wasChecked ?
      `"${changedItemName}" was packed ✓` :
      `"${changedItemName}" was unchecked`;

    const memberDocs = await Promise.all(
      tripData.memberUids.map((uid) => db.collection("users").doc(uid).get())
    );

    const tokens: string[] = [];
    for (const doc of memberDocs) {
      if (!doc.exists) continue;
      const userData = doc.data() as {fcmTokens?: string[]};
      if (userData.fcmTokens) tokens.push(...userData.fcmTokens);
    }

    if (tokens.length === 0) return;

    await admin.messaging().sendEachForMulticast({
      notification: {title: `${tripData.name} — Packing List`, body},
      data: {tripId, type: "packing_change"},
      tokens,
    });
  });
