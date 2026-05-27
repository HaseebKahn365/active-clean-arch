import { test, beforeEach } from "node:test";
import assert from "node:assert/strict";

const RUN_EMULATOR_TESTS = process.env.RUN_FIRESTORE_EMULATOR_TESTS === "1";
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT ?? "demo-active";

import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

import { getTreeSnapshot, moveNode } from "../src/tools/activity_tools";

const UID = "user_123";

function initAdmin() {
  if (getApps().length === 0) {
    initializeApp({ projectId: process.env.GCLOUD_PROJECT });
  }
}

async function clearFirestore() {
  const db = getFirestore();
  const cols = ["activities", "activity_events", "count_records", "ai_tool_audits"];
  for (const c of cols) {
    const snap = await db.collection(c).get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  }
}

beforeEach(async () => {
  if (!RUN_EMULATOR_TESTS) return;
  initAdmin();
  await clearFirestore();
});

test("getTreeSnapshot(rootsOnly) returns only roots", { skip: !RUN_EMULATOR_TESTS }, async () => {
  const db = getFirestore();
  await db.collection("activities").doc("root").set({
    userId: UID,
    id: "root",
    name: "Root",
    description: "",
    parent_id: null,
    children_ids: JSON.stringify(["child"]),
    status: "ActivityStatus.idle",
    started_at: null,
    total_seconds: 0,
    goal_seconds: 0,
    type: "ActivityType.timeBased",
    is_pinned: 0,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  });
  await db.collection("activities").doc("child").set({
    userId: UID,
    id: "child",
    name: "Child",
    description: "",
    parent_id: "root",
    children_ids: JSON.stringify([]),
    status: "ActivityStatus.idle",
    started_at: null,
    total_seconds: 0,
    goal_seconds: 0,
    type: "ActivityType.timeBased",
    is_pinned: 0,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  });

  const res = await getTreeSnapshot(UID, { scope: "rootsOnly" });
  assert.equal(res.ok, true);
  if (!res.ok) return;
  const nodes = (res.data as any).nodes as any[];
  assert.equal(Array.isArray(nodes), true);
  assert.equal(nodes.length, 1);
  assert.equal(nodes[0].id, "root");
});

test("moveNode updates parent children_ids and node parent_id", { skip: !RUN_EMULATOR_TESTS }, async () => {
  const db = getFirestore();
  await db.collection("activities").doc("p1").set({
    userId: UID,
    id: "p1",
    name: "P1",
    description: "",
    parent_id: null,
    children_ids: JSON.stringify(["a"]),
    status: "ActivityStatus.idle",
    started_at: null,
    total_seconds: 0,
    goal_seconds: 0,
    type: "ActivityType.timeBased",
    is_pinned: 0,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  });
  await db.collection("activities").doc("p2").set({
    userId: UID,
    id: "p2",
    name: "P2",
    description: "",
    parent_id: null,
    children_ids: JSON.stringify([]),
    status: "ActivityStatus.idle",
    started_at: null,
    total_seconds: 0,
    goal_seconds: 0,
    type: "ActivityType.timeBased",
    is_pinned: 0,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  });
  await db.collection("activities").doc("a").set({
    userId: UID,
    id: "a",
    name: "A",
    description: "",
    parent_id: "p1",
    children_ids: JSON.stringify([]),
    status: "ActivityStatus.idle",
    started_at: null,
    total_seconds: 0,
    goal_seconds: 0,
    type: "ActivityType.timeBased",
    is_pinned: 0,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  });

  const res = await moveNode(UID, { requestId: "r1", nodeId: "a", newParentId: "p2", newIndex: 0 });
  assert.equal(res.ok, true);

  const p1 = (await db.collection("activities").doc("p1").get()).data()!;
  const p2 = (await db.collection("activities").doc("p2").get()).data()!;
  const a = (await db.collection("activities").doc("a").get()).data()!;

  assert.deepEqual(JSON.parse(p1.children_ids), []);
  assert.deepEqual(JSON.parse(p2.children_ids), ["a"]);
  assert.equal(a.parent_id, "p2");
});

