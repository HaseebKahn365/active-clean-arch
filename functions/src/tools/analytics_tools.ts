import { getFirestore } from "firebase-admin/firestore";
import { z } from "zod";
import { err, ok, type ToolEnvelope } from "../shared/envelope";

function requireUid(uid: string | undefined): uid is string {
  return typeof uid === "string" && uid.length > 0;
}

function rangeStart(now: Date, range: "today" | "week" | "month") {
  const d = new Date(now);
  if (range === "today") {
    d.setHours(0, 0, 0, 0);
    return d;
  }
  if (range === "week") {
    const day = d.getDay(); // 0..6 (Sun..Sat)
    const diff = (day + 6) % 7; // Monday as start
    d.setDate(d.getDate() - diff);
    d.setHours(0, 0, 0, 0);
    return d;
  }
  // month
  d.setDate(1);
  d.setHours(0, 0, 0, 0);
  return d;
}

export async function getAnalytics(uid: string | undefined, input: unknown): Promise<ToolEnvelope> {
  if (!requireUid(uid)) return err("UNAUTHENTICATED", "Sign-in is required.", false);

  const schema = z.object({
    range: z.enum(["today", "week", "month"]),
    breakdown: z.enum(["byActivity", "byRoot", "overall"]),
    limit: z.number().int().min(1).max(50).optional(),
  });
  const parsed = schema.safeParse(input);
  if (!parsed.success) return err("INVALID_ARGUMENT", parsed.error.message, false);

  const { range, breakdown, limit } = parsed.data;
  const now = new Date();
  const start = rangeStart(now, range);
  const startIso = start.toISOString();

  const db = getFirestore();

  // Duration analytics from activity_events.
  // NOTE: current client stores `duration_delta` for pauses and periodic running updates.
  // We approximate range totals by summing events whose `timestamp` is inside the range
  // and whose `next_status` is not `ActivityStatus.running` (terminal transitions).
  const eventsSnap = await db
    .collection("activity_events")
    .where("userId", "==", uid)
    .where("timestamp", ">=", startIso)
    .get();

  const durationByActivity = new Map<string, number>();
  for (const d of eventsSnap.docs) {
    const e = d.data() as any;
    const next = (e.next_status ?? "").toString();
    if (next === "ActivityStatus.running") continue;
    const activityId = (e.activity_id ?? "").toString();
    const delta = Number(e.duration_delta ?? 0);
    if (!activityId) continue;
    durationByActivity.set(activityId, (durationByActivity.get(activityId) ?? 0) + (Number.isFinite(delta) ? delta : 0));
  }

  // Count analytics from count_records.
  const countsSnap = await db
    .collection("count_records")
    .where("userId", "==", uid)
    .where("timestamp", ">=", startIso)
    .get();
  const countByActivity = new Map<string, number>();
  for (const d of countsSnap.docs) {
    const r = d.data() as any;
    const activityId = (r.activity_id ?? "").toString();
    const v = Number(r.value ?? 0);
    if (!activityId) continue;
    countByActivity.set(activityId, (countByActivity.get(activityId) ?? 0) + (Number.isFinite(v) ? v : 0));
  }

  const overallSeconds = Array.from(durationByActivity.values()).reduce((a, b) => a + b, 0);
  const overallCount = Array.from(countByActivity.values()).reduce((a, b) => a + b, 0);

  if (breakdown === "overall") {
    return ok({
      range,
      overall: { seconds: overallSeconds, count: overallCount },
    });
  }

  const items = Array.from(
    new Set<string>([...durationByActivity.keys(), ...countByActivity.keys()]),
  ).map((activityId) => ({
    activityId,
    seconds: durationByActivity.get(activityId) ?? 0,
    count: countByActivity.get(activityId) ?? 0,
  }));

  items.sort((a, b) => b.seconds - a.seconds);

  return ok({
    range,
    breakdown,
    items: items.slice(0, limit ?? 20),
    overall: { seconds: overallSeconds, count: overallCount },
    note: "Duration totals are approximations based on terminal events in the selected range.",
  });
}

