"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getTreeSnapshot = getTreeSnapshot;
exports.getActivityNamesYaml = getActivityNamesYaml;
exports.getRunningActivities = getRunningActivities;
exports.getNode = getNode;
exports.searchNodes = searchNodes;
exports.addCount = addCount;
exports.getActivityTotal = getActivityTotal;
exports.getBreadcrumbs = getBreadcrumbs;
exports.togglePin = togglePin;
exports.updateActivityDuration = updateActivityDuration;
exports.checkpointActivity = checkpointActivity;
exports.completeActivity = completeActivity;
exports.clearAllData = clearAllData;
exports.createNode = createNode;
exports.updateNode = updateNode;
exports.moveNode = moveNode;
exports.deleteNode = deleteNode;
exports.startActivity = startActivity;
exports.pauseActivity = pauseActivity;
exports.stopActivity = stopActivity;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const uuid_1 = require("uuid");
const envelope_1 = require("../shared/envelope");
const firestore_schema_1 = require("../shared/firestore_schema");
const ACTIVITY_STATUS = {
    idle: "ActivityStatus.idle",
    running: "ActivityStatus.running",
    paused: "ActivityStatus.paused",
    completed: "ActivityStatus.completed",
};
const ACTIVITY_TYPE = {
    timeBased: "ActivityType.timeBased",
    countBased: "ActivityType.countBased",
};
function nowIso() {
    return new Date().toISOString();
}
function requireUid(uid) {
    return typeof uid === "string" && uid.length > 0;
}
async function getTreeSnapshot(uid, input) {
    if (!requireUid(uid))
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    const schema = zod_1.z.object({
        scope: zod_1.z.enum(["full", "rootsOnly", "subtree"]),
        rootId: zod_1.z.string().optional().nullable(),
        includeStats: zod_1.z.boolean().optional(),
    });
    const parsed = schema.safeParse(input);
    if (!parsed.success)
        return (0, envelope_1.err)("INVALID_ARGUMENT", parsed.error.message, false);
    const { scope, rootId } = parsed.data;
    if (scope === "subtree" && !rootId)
        return (0, envelope_1.err)("INVALID_ARGUMENT", "rootId is required when scope=subtree.", false);
    const db = (0, firestore_1.getFirestore)();
    const snap = await db.collection("activities").where("userId", "==", uid).get();
    const nodes = snap.docs.map((d) => {
        const data = d.data();
        return { ...data, _docId: d.id, children: (0, firestore_schema_1.parseChildrenIds)(data.children_ids) };
    });
    let filtered = nodes;
    if (scope === "rootsOnly") {
        filtered = nodes.filter((n) => !n.parent_id);
    }
    else if (scope === "subtree" && rootId) {
        const byId = new Map(nodes.map((n) => [n.id, n]));
        const keep = new Set();
        const stack = [rootId];
        while (stack.length) {
            const id = stack.pop();
            if (keep.has(id))
                continue;
            keep.add(id);
            const node = byId.get(id);
            if (node) {
                for (const c of node.children)
                    stack.push(c);
            }
        }
        filtered = nodes.filter((n) => keep.has(n.id));
    }
    return (0, envelope_1.ok)({
        nodes: filtered.map((n) => ({
            id: n.id,
            name: n.name,
            description: n.description ?? "",
            parentId: n.parent_id ?? null,
            childrenIds: n.children,
            status: n.status,
            startedAt: n.started_at ?? null,
            totalSeconds: n.total_seconds,
            goalSeconds: n.goal_seconds ?? 0,
            type: n.type,
            isPinned: n.is_pinned === 1,
            createdAt: n.created_at,
            updatedAt: n.updated_at,
        })),
    });
}
async function getActivityNamesYaml(uid, input) {
    if (!requireUid(uid))
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    const schema = zod_1.z.object({
        includeIds: zod_1.z.boolean().optional(),
        includeHierarchy: zod_1.z.boolean().optional(),
    });
    const parsed = schema.safeParse(input);
    if (!parsed.success)
        return (0, envelope_1.err)("INVALID_ARGUMENT", parsed.error.message, false);
    const includeIds = parsed.data.includeIds ?? true;
    const includeHierarchy = parsed.data.includeHierarchy ?? true;
    const db = (0, firestore_1.getFirestore)();
    const snap = await db.collection("activities").where("userId", "==", uid).get();
    const nodes = snap.docs.map((d) => {
        const a = d.data();
        return {
            id: (a.id ?? d.id).toString(),
            name: (a.name ?? "").toString(),
            parentId: a.parent_id ? a.parent_id.toString() : null,
            childrenIds: (0, firestore_schema_1.parseChildrenIds)(a.children_ids),
        };
    });
    const byId = new Map(nodes.map((n) => [n.id, n]));
    const roots = nodes.filter((n) => !n.parentId);
    const esc = (s) => `"${String(s).replaceAll('"', '\\"')}"`;
    const renderNode = (n, indent) => {
        const pad = "  ".repeat(indent);
        const idPart = includeIds ? ` id: ${esc(n.id)}` : "";
        let out = `${pad}- name: ${esc(n.name)}${idPart}\n`;
        if (includeHierarchy && Array.isArray(n.childrenIds) && n.childrenIds.length > 0) {
            out += `${pad}  children:\n`;
            for (const cid of n.childrenIds) {
                const child = byId.get(cid);
                if (child)
                    out += renderNode(child, indent + 2);
            }
        }
        return out;
    };
    var yaml = "activities:\n";
    for (const r of roots) {
        yaml += renderNode(r, 1);
    }
    return (0, envelope_1.ok)({ yaml, count: nodes.length });
}
async function getRunningActivities(uid, _input) {
    if (!requireUid(uid))
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    const db = (0, firestore_1.getFirestore)();
    const snap = await db
        .collection("activities")
        .where("userId", "==", uid)
        .where("status", "==", ACTIVITY_STATUS.running)
        .get();
    const running = snap.docs.map((d) => {
        const data = d.data();
        return {
            id: data.id,
            name: data.name,
            startedAt: data.started_at ?? null,
            totalSeconds: data.total_seconds ?? 0,
            parentId: data.parent_id ?? null,
        };
    });
    return (0, envelope_1.ok)({ running });
}
async function getNode(uid, input) {
    if (!requireUid(uid))
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    const schema = zod_1.z.object({ nodeId: zod_1.z.string().min(1) });
    const parsed = schema.safeParse(input);
    if (!parsed.success)
        return (0, envelope_1.err)("INVALID_ARGUMENT", parsed.error.message, false);
    const { nodeId } = parsed.data;
    const db = (0, firestore_1.getFirestore)();
    const doc = await db.collection("activities").doc(nodeId).get();
    if (!doc.exists)
        return (0, envelope_1.err)("NOT_FOUND", "Activity not found.", false);
    const data = doc.data();
    if (data.userId !== uid)
        return (0, envelope_1.err)("PERMISSION_DENIED", "Not allowed.", false);
    return (0, envelope_1.ok)({
        node: {
            ...data,
            childrenIds: (0, firestore_schema_1.parseChildrenIds)(data.children_ids),
            isPinned: data.is_pinned === 1,
        },
    });
}
async function searchNodes(uid, input) {
    if (!requireUid(uid))
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    const schema = zod_1.z.object({
        query: zod_1.z.string().min(1),
        status: zod_1.z.enum(["idle", "running", "paused", "completed"]).optional().nullable(),
        type: zod_1.z.enum(["timeBased", "countBased"]).optional().nullable(),
        pinnedOnly: zod_1.z.boolean().optional(),
        limit: zod_1.z.number().int().min(1).max(50).optional(),
    });
    const parsed = schema.safeParse(input);
    if (!parsed.success)
        return (0, envelope_1.err)("INVALID_ARGUMENT", parsed.error.message, false);
    const { query, status, type, pinnedOnly, limit } = parsed.data;
    const db = (0, firestore_1.getFirestore)();
    const snap = await db.collection("activities").where("userId", "==", uid).get();
    const q = query.toLowerCase();
    const matches = snap.docs
        .map((d) => d.data())
        .filter((a) => {
        if (pinnedOnly && a.is_pinned !== 1)
            return false;
        if (status && a.status !== ACTIVITY_STATUS[status])
            return false;
        if (type && a.type !== ACTIVITY_TYPE[type])
            return false;
        const name = (a.name ?? "").toString().toLowerCase();
        const desc = (a.description ?? "").toString().toLowerCase();
        return name.includes(q) || desc.includes(q);
    })
        .slice(0, limit ?? 20)
        .map((a) => ({ id: a.id, name: a.name, parentId: a.parent_id ?? null, status: a.status, type: a.type }));
    return (0, envelope_1.ok)({ matches });
}
async function addCount(uid, input) {
    if (!requireUid(uid))
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    const schema = zod_1.z.object({
        requestId: zod_1.z.string().min(1),
        nodeId: zod_1.z.string().min(1),
        value: zod_1.z.number(),
    });
    const parsed = schema.safeParse(input);
    if (!parsed.success)
        return (0, envelope_1.err)("INVALID_ARGUMENT", parsed.error.message, false);
    const { nodeId, value } = parsed.data;
    const db = (0, firestore_1.getFirestore)();
    const activityRef = db.collection("activities").doc(nodeId);
    const activitySnap = await activityRef.get();
    if (!activitySnap.exists)
        return (0, envelope_1.err)("NOT_FOUND", "Activity not found.", false);
    const activity = activitySnap.data();
    if (activity.userId !== uid)
        return (0, envelope_1.err)("PERMISSION_DENIED", "Not allowed.", false);
    if ((activity.type ?? "") !== ACTIVITY_TYPE.countBased) {
        return (0, envelope_1.err)("FAILED_PRECONDITION", "Activity is not count-based.", false);
    }
    const id = (0, uuid_1.v4)();
    const now = nowIso();
    await db.collection("count_records").doc(id).set({
        userId: uid,
        id,
        activity_id: nodeId,
        timestamp: now,
        value,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    return (0, envelope_1.ok)({ id, activityId: nodeId, value, timestamp: now });
}
async function getActivityTotal(uid, input) {
    if (!requireUid(uid))
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    const schema = zod_1.z.object({ nodeId: zod_1.z.string().min(1), range: zod_1.z.enum(["today", "week", "month"]).optional().nullable() });
    const parsed = schema.safeParse(input);
    if (!parsed.success)
        return (0, envelope_1.err)("INVALID_ARGUMENT", parsed.error.message, false);
    const { nodeId, range } = parsed.data;
    const db = (0, firestore_1.getFirestore)();
    const activitySnap = await db.collection("activities").doc(nodeId).get();
    if (!activitySnap.exists)
        return (0, envelope_1.err)("NOT_FOUND", "Activity not found.", false);
    const activity = activitySnap.data();
    if (activity.userId !== uid)
        return (0, envelope_1.err)("PERMISSION_DENIED", "Not allowed.", false);
    if ((activity.type ?? "") !== ACTIVITY_TYPE.countBased) {
        return (0, envelope_1.err)("FAILED_PRECONDITION", "Activity is not count-based.", false);
    }
    let q = db.collection("count_records").where("userId", "==", uid).where("activity_id", "==", nodeId);
    if (range) {
        const now = new Date();
        const start = new Date(now);
        if (range === "today") {
            start.setHours(0, 0, 0, 0);
        }
        else if (range === "week") {
            const day = start.getDay();
            const diff = (day + 6) % 7;
            start.setDate(start.getDate() - diff);
            start.setHours(0, 0, 0, 0);
        }
        else {
            start.setDate(1);
            start.setHours(0, 0, 0, 0);
        }
        q = q.where("timestamp", ">=", start.toISOString());
    }
    const snap = await q.get();
    const total = snap.docs.reduce((sum, d) => sum + Number(d.data().value ?? 0), 0);
    return (0, envelope_1.ok)({ activityId: nodeId, total, range: range ?? null });
}
async function getBreadcrumbs(uid, input) {
    if (!requireUid(uid))
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    const schema = zod_1.z.object({ nodeId: zod_1.z.string().min(1) });
    const parsed = schema.safeParse(input);
    if (!parsed.success)
        return (0, envelope_1.err)("INVALID_ARGUMENT", parsed.error.message, false);
    const { nodeId } = parsed.data;
    const db = (0, firestore_1.getFirestore)();
    const breadcrumbs = [];
    let currentId = nodeId;
    for (let i = 0; i < 50 && currentId; i++) {
        const snap = await db.collection("activities").doc(currentId).get();
        if (!snap.exists)
            break;
        const a = snap.data();
        if (a.userId !== uid)
            return (0, envelope_1.err)("PERMISSION_DENIED", "Not allowed.", false);
        breadcrumbs.unshift({ id: a.id, name: a.name, parentId: a.parent_id ?? null });
        currentId = a.parent_id ?? null;
    }
    return (0, envelope_1.ok)({ breadcrumbs });
}
async function togglePin(uid, input) {
    if (!requireUid(uid))
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    const schema = zod_1.z.object({ requestId: zod_1.z.string().min(1), nodeId: zod_1.z.string().min(1) });
    const parsed = schema.safeParse(input);
    if (!parsed.success)
        return (0, envelope_1.err)("INVALID_ARGUMENT", parsed.error.message, false);
    const { nodeId } = parsed.data;
    const db = (0, firestore_1.getFirestore)();
    const ref = db.collection("activities").doc(nodeId);
    await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists)
            throw new Error("NOT_FOUND");
        const a = snap.data();
        if (a.userId !== uid)
            throw new Error("PERMISSION_DENIED");
        const next = a.is_pinned === 1 ? 0 : 1;
        tx.update(ref, { is_pinned: next, updated_at: nowIso(), updatedAt: firestore_1.FieldValue.serverTimestamp() });
    });
    return (0, envelope_1.ok)({ nodeId });
}
async function updateActivityDuration(uid, input) {
    if (!requireUid(uid))
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    const schema = zod_1.z.object({ requestId: zod_1.z.string().min(1), nodeId: zod_1.z.string().min(1), newSeconds: zod_1.z.number().int().min(0) });
    const parsed = schema.safeParse(input);
    if (!parsed.success)
        return (0, envelope_1.err)("INVALID_ARGUMENT", parsed.error.message, false);
    const { nodeId, newSeconds } = parsed.data;
    const db = (0, firestore_1.getFirestore)();
    const ref = db.collection("activities").doc(nodeId);
    await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists)
            throw new Error("NOT_FOUND");
        const a = snap.data();
        if (a.userId !== uid)
            throw new Error("PERMISSION_DENIED");
        if (a.status === ACTIVITY_STATUS.running)
            throw new Error("FAILED_PRECONDITION");
        tx.update(ref, {
            total_seconds: newSeconds,
            started_at: null,
            updated_at: nowIso(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
    });
    return (0, envelope_1.ok)({ nodeId, totalSeconds: newSeconds });
}
async function checkpointActivity(uid, input) {
    if (!requireUid(uid))
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    const schema = zod_1.z.object({ requestId: zod_1.z.string().min(1), nodeId: zod_1.z.string().min(1) });
    const parsed = schema.safeParse(input);
    if (!parsed.success)
        return (0, envelope_1.err)("INVALID_ARGUMENT", parsed.error.message, false);
    const { nodeId } = parsed.data;
    const db = (0, firestore_1.getFirestore)();
    const now = new Date();
    const nowISO = now.toISOString();
    await db.runTransaction(async (tx) => {
        const ref = db.collection("activities").doc(nodeId);
        const snap = await tx.get(ref);
        if (!snap.exists)
            throw new Error("NOT_FOUND");
        const a = snap.data();
        if (a.userId !== uid)
            throw new Error("PERMISSION_DENIED");
        if (a.status !== ACTIVITY_STATUS.running || !a.started_at)
            throw new Error("FAILED_PRECONDITION");
        const started = new Date(a.started_at);
        const delta = Math.max(0, Math.floor((now.getTime() - started.getTime()) / 1000));
        tx.update(ref, {
            total_seconds: (a.total_seconds ?? 0) + delta,
            started_at: nowISO,
            updated_at: nowISO,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
    });
    return (0, envelope_1.ok)({ nodeId });
}
async function completeActivity(uid, input) {
    if (!requireUid(uid))
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    const schema = zod_1.z.object({ requestId: zod_1.z.string().min(1), nodeId: zod_1.z.string().min(1) });
    const parsed = schema.safeParse(input);
    if (!parsed.success)
        return (0, envelope_1.err)("INVALID_ARGUMENT", parsed.error.message, false);
    const { nodeId } = parsed.data;
    // Pause first if running, then set completed.
    await pauseActivity(uid, { requestId: (0, uuid_1.v4)(), nodeId });
    const db = (0, firestore_1.getFirestore)();
    await db.runTransaction(async (tx) => {
        const ref = db.collection("activities").doc(nodeId);
        const snap = await tx.get(ref);
        if (!snap.exists)
            throw new Error("NOT_FOUND");
        const a = snap.data();
        if (a.userId !== uid)
            throw new Error("PERMISSION_DENIED");
        tx.update(ref, { status: ACTIVITY_STATUS.completed, started_at: null, updated_at: nowIso(), updatedAt: firestore_1.FieldValue.serverTimestamp() });
    });
    return (0, envelope_1.ok)({ nodeId, status: ACTIVITY_STATUS.completed });
}
async function clearAllData(uid, input) {
    if (!requireUid(uid))
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    const schema = zod_1.z.object({ requestId: zod_1.z.string().min(1), confirmed: zod_1.z.boolean() });
    const parsed = schema.safeParse(input);
    if (!parsed.success)
        return (0, envelope_1.err)("INVALID_ARGUMENT", parsed.error.message, false);
    if (!parsed.data.confirmed)
        return (0, envelope_1.err)("NEEDS_CONFIRMATION", "clearAllData requires confirmed=true.", false);
    const db = (0, firestore_1.getFirestore)();
    const cols = ["activities", "activity_events", "count_records"];
    for (const col of cols) {
        const snap = await db.collection(col).where("userId", "==", uid).get();
        const batches = [];
        let batch = db.batch();
        let i = 0;
        for (const d of snap.docs) {
            batch.delete(d.ref);
            i++;
            if (i % 400 === 0) {
                batches.push(batch);
                batch = db.batch();
            }
        }
        batches.push(batch);
        for (const b of batches)
            await b.commit();
    }
    return (0, envelope_1.ok)({ cleared: true });
}
async function createNode(uid, input) {
    if (!requireUid(uid))
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    const schema = zod_1.z.object({
        requestId: zod_1.z.string().min(1),
        name: zod_1.z.string().min(1),
        description: zod_1.z.string().optional().nullable(),
        parentId: zod_1.z.string().optional().nullable(),
        goalSeconds: zod_1.z.number().int().min(0).optional(),
        type: zod_1.z.enum(["timeBased", "countBased"]),
        isPinned: zod_1.z.boolean().optional(),
    });
    const parsed = schema.safeParse(input);
    if (!parsed.success)
        return (0, envelope_1.err)("INVALID_ARGUMENT", parsed.error.message, false);
    const { name, description, parentId, goalSeconds, type, isPinned } = parsed.data;
    const db = (0, firestore_1.getFirestore)();
    const id = (0, uuid_1.v4)();
    const createdAt = nowIso();
    const updatedAt = createdAt;
    const docData = {
        userId: uid,
        id,
        name,
        description: description ?? "",
        parent_id: parentId ?? null,
        children_ids: "[]",
        status: ACTIVITY_STATUS.idle,
        started_at: null,
        total_seconds: 0,
        goal_seconds: goalSeconds ?? 0,
        type: ACTIVITY_TYPE[type],
        is_pinned: isPinned ? 1 : 0,
        created_at: createdAt,
        updated_at: updatedAt,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    };
    // Validate shape to avoid writing incompatible documents.
    const validation = firestore_schema_1.activityDocSchema.safeParse(docData);
    if (!validation.success)
        return (0, envelope_1.err)("INTERNAL", validation.error.message, true);
    await db.runTransaction(async (tx) => {
        const docRef = db.collection("activities").doc(id);
        tx.set(docRef, docData);
        if (parentId) {
            const parentRef = db.collection("activities").doc(parentId);
            const parentSnap = await tx.get(parentRef);
            if (parentSnap.exists) {
                const parentData = parentSnap.data();
                if (parentData.userId !== uid)
                    throw new Error("PERMISSION_DENIED");
                const children = (0, firestore_schema_1.parseChildrenIds)(parentData.children_ids);
                if (!children.includes(id))
                    children.push(id);
                tx.update(parentRef, {
                    children_ids: (0, firestore_schema_1.serializeChildrenIds)(children),
                    updated_at: nowIso(),
                    updatedAt: firestore_1.FieldValue.serverTimestamp(),
                });
            }
        }
    });
    return (0, envelope_1.ok)({ id });
}
async function updateNode(uid, input) {
    if (!requireUid(uid))
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    const schema = zod_1.z.object({
        requestId: zod_1.z.string().min(1),
        nodeId: zod_1.z.string().min(1),
        patch: zod_1.z
            .object({
            name: zod_1.z.string().min(1).optional().nullable(),
            description: zod_1.z.string().optional().nullable(),
            goalSeconds: zod_1.z.number().int().min(0).optional().nullable(),
            isPinned: zod_1.z.boolean().optional().nullable(),
            type: zod_1.z.enum(["timeBased", "countBased"]).optional().nullable(),
        })
            .strict(),
    });
    const parsed = schema.safeParse(input);
    if (!parsed.success)
        return (0, envelope_1.err)("INVALID_ARGUMENT", parsed.error.message, false);
    const { nodeId, patch } = parsed.data;
    const db = (0, firestore_1.getFirestore)();
    const ref = db.collection("activities").doc(nodeId);
    const snap = await ref.get();
    if (!snap.exists)
        return (0, envelope_1.err)("NOT_FOUND", "Activity not found.", false);
    if (snap.data().userId !== uid)
        return (0, envelope_1.err)("PERMISSION_DENIED", "Not allowed.", false);
    const update = {
        updated_at: nowIso(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    };
    if (patch.name != null)
        update.name = patch.name;
    if (patch.description != null)
        update.description = patch.description;
    if (patch.goalSeconds != null)
        update.goal_seconds = patch.goalSeconds;
    if (patch.isPinned != null)
        update.is_pinned = patch.isPinned ? 1 : 0;
    if (patch.type != null)
        update.type = ACTIVITY_TYPE[patch.type];
    await ref.set(update, { merge: true });
    return (0, envelope_1.ok)({ nodeId });
}
async function moveNode(uid, input) {
    if (!requireUid(uid))
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    const schema = zod_1.z.object({
        requestId: zod_1.z.string().min(1),
        nodeId: zod_1.z.string().min(1),
        newParentId: zod_1.z.string().optional().nullable(),
        newIndex: zod_1.z.number().int().min(0).optional().nullable(),
    });
    const parsed = schema.safeParse(input);
    if (!parsed.success)
        return (0, envelope_1.err)("INVALID_ARGUMENT", parsed.error.message, false);
    const { nodeId, newParentId, newIndex } = parsed.data;
    if (nodeId === newParentId)
        return (0, envelope_1.err)("INVALID_ARGUMENT", "Cannot move a node into itself.", false);
    const db = (0, firestore_1.getFirestore)();
    await db.runTransaction(async (tx) => {
        const nodeRef = db.collection("activities").doc(nodeId);
        const nodeSnap = await tx.get(nodeRef);
        if (!nodeSnap.exists)
            throw new Error("NOT_FOUND");
        const node = nodeSnap.data();
        if (node.userId !== uid)
            throw new Error("PERMISSION_DENIED");
        const oldParentId = node.parent_id ?? null;
        // Cycle prevention: disallow moving into descendant.
        if (newParentId) {
            const byId = new Map();
            const all = await tx.get(db.collection("activities").where("userId", "==", uid));
            for (const d of all.docs)
                byId.set(d.id, d.data());
            const stack = [nodeId];
            const descendants = new Set();
            while (stack.length) {
                const id = stack.pop();
                if (descendants.has(id))
                    continue;
                descendants.add(id);
                const a = byId.get(id);
                if (a) {
                    for (const c of (0, firestore_schema_1.parseChildrenIds)(a.children_ids))
                        stack.push(c);
                }
            }
            if (descendants.has(newParentId))
                throw new Error("CYCLE");
        }
        // Remove from old parent.
        if (oldParentId) {
            const oldParentRef = db.collection("activities").doc(oldParentId);
            const oldParentSnap = await tx.get(oldParentRef);
            if (oldParentSnap.exists) {
                const oldParent = oldParentSnap.data();
                if (oldParent.userId !== uid)
                    throw new Error("PERMISSION_DENIED");
                const children = (0, firestore_schema_1.parseChildrenIds)(oldParent.children_ids).filter((id) => id !== nodeId);
                tx.update(oldParentRef, {
                    children_ids: (0, firestore_schema_1.serializeChildrenIds)(children),
                    updated_at: nowIso(),
                    updatedAt: firestore_1.FieldValue.serverTimestamp(),
                });
            }
        }
        // Add to new parent.
        if (newParentId) {
            const newParentRef = db.collection("activities").doc(newParentId);
            const newParentSnap = await tx.get(newParentRef);
            if (!newParentSnap.exists)
                throw new Error("NEW_PARENT_NOT_FOUND");
            const newParent = newParentSnap.data();
            if (newParent.userId !== uid)
                throw new Error("PERMISSION_DENIED");
            const children = (0, firestore_schema_1.parseChildrenIds)(newParent.children_ids).filter((id) => id !== nodeId);
            const idx = newIndex == null ? children.length : Math.min(Math.max(newIndex, 0), children.length);
            children.splice(idx, 0, nodeId);
            tx.update(newParentRef, {
                children_ids: (0, firestore_schema_1.serializeChildrenIds)(children),
                updated_at: nowIso(),
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            });
        }
        // Update node parent.
        tx.update(nodeRef, {
            parent_id: newParentId ?? null,
            updated_at: nowIso(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
    });
    return (0, envelope_1.ok)({ nodeId, newParentId: newParentId ?? null });
}
async function deleteNode(uid, input) {
    if (!requireUid(uid))
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    const schema = zod_1.z.object({
        requestId: zod_1.z.string().min(1),
        nodeId: zod_1.z.string().min(1),
        mode: zod_1.z.enum(["soft", "hard"]).optional(),
    });
    const parsed = schema.safeParse(input);
    if (!parsed.success)
        return (0, envelope_1.err)("INVALID_ARGUMENT", parsed.error.message, false);
    const { nodeId, mode } = parsed.data;
    const db = (0, firestore_1.getFirestore)();
    await db.runTransaction(async (tx) => {
        const ref = db.collection("activities").doc(nodeId);
        const snap = await tx.get(ref);
        if (!snap.exists)
            throw new Error("NOT_FOUND");
        const data = snap.data();
        if (data.userId !== uid)
            throw new Error("PERMISSION_DENIED");
        const children = (0, firestore_schema_1.parseChildrenIds)(data.children_ids);
        if (children.length > 0)
            throw new Error("HAS_CHILDREN");
        const parentId = data.parent_id ?? null;
        if (parentId) {
            const parentRef = db.collection("activities").doc(parentId);
            const parentSnap = await tx.get(parentRef);
            if (parentSnap.exists) {
                const parent = parentSnap.data();
                if (parent.userId !== uid)
                    throw new Error("PERMISSION_DENIED");
                const updated = (0, firestore_schema_1.parseChildrenIds)(parent.children_ids).filter((id) => id !== nodeId);
                tx.update(parentRef, {
                    children_ids: (0, firestore_schema_1.serializeChildrenIds)(updated),
                    updated_at: nowIso(),
                    updatedAt: firestore_1.FieldValue.serverTimestamp(),
                });
            }
        }
        if (mode === "hard") {
            tx.delete(ref);
        }
        else {
            // Soft-delete via archive fields (ignored by current client model mapping).
            tx.update(ref, {
                archived: true,
                archived_at: nowIso(),
                updated_at: nowIso(),
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            });
        }
    });
    return (0, envelope_1.ok)({ nodeId, mode: mode ?? "soft" });
}
async function startActivity(uid, input) {
    if (!requireUid(uid))
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    const schema = zod_1.z.object({ requestId: zod_1.z.string().min(1), nodeId: zod_1.z.string().min(1) });
    const parsed = schema.safeParse(input);
    if (!parsed.success)
        return (0, envelope_1.err)("INVALID_ARGUMENT", parsed.error.message, false);
    const { nodeId } = parsed.data;
    const db = (0, firestore_1.getFirestore)();
    const now = new Date();
    const nowISO = now.toISOString();
    await db.runTransaction(async (tx) => {
        // Pause any currently running activities.
        const runningSnap = await tx.get(db.collection("activities").where("userId", "==", uid).where("status", "==", ACTIVITY_STATUS.running));
        for (const d of runningSnap.docs) {
            const a = d.data();
            const startedAt = a.started_at ? new Date(a.started_at) : null;
            const delta = startedAt ? Math.max(0, Math.floor((now.getTime() - startedAt.getTime()) / 1000)) : 0;
            tx.update(d.ref, {
                status: ACTIVITY_STATUS.paused,
                started_at: null,
                total_seconds: (a.total_seconds ?? 0) + delta,
                updated_at: nowISO,
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            });
        }
        const ref = db.collection("activities").doc(nodeId);
        const snap = await tx.get(ref);
        if (!snap.exists)
            throw new Error("NOT_FOUND");
        const a = snap.data();
        if (a.userId !== uid)
            throw new Error("PERMISSION_DENIED");
        tx.update(ref, {
            status: ACTIVITY_STATUS.running,
            started_at: nowISO,
            updated_at: nowISO,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
    });
    return (0, envelope_1.ok)({ nodeId, status: ACTIVITY_STATUS.running });
}
async function pauseActivity(uid, input) {
    if (!requireUid(uid))
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    const schema = zod_1.z.object({ requestId: zod_1.z.string().min(1), nodeId: zod_1.z.string().min(1) });
    const parsed = schema.safeParse(input);
    if (!parsed.success)
        return (0, envelope_1.err)("INVALID_ARGUMENT", parsed.error.message, false);
    const { nodeId } = parsed.data;
    const db = (0, firestore_1.getFirestore)();
    const now = new Date();
    const nowISO = now.toISOString();
    await db.runTransaction(async (tx) => {
        const ref = db.collection("activities").doc(nodeId);
        const snap = await tx.get(ref);
        if (!snap.exists)
            throw new Error("NOT_FOUND");
        const a = snap.data();
        if (a.userId !== uid)
            throw new Error("PERMISSION_DENIED");
        if (a.status !== ACTIVITY_STATUS.running)
            return;
        const startedAt = a.started_at ? new Date(a.started_at) : null;
        const delta = startedAt ? Math.max(0, Math.floor((now.getTime() - startedAt.getTime()) / 1000)) : 0;
        tx.update(ref, {
            status: ACTIVITY_STATUS.paused,
            started_at: null,
            total_seconds: (a.total_seconds ?? 0) + delta,
            updated_at: nowISO,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
    });
    return (0, envelope_1.ok)({ nodeId, status: ACTIVITY_STATUS.paused });
}
async function stopActivity(uid, input) {
    if (!requireUid(uid))
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    const schema = zod_1.z.object({
        requestId: zod_1.z.string().min(1),
        nodeId: zod_1.z.string().min(1),
        markCompleted: zod_1.z.boolean().optional(),
    });
    const parsed = schema.safeParse(input);
    if (!parsed.success)
        return (0, envelope_1.err)("INVALID_ARGUMENT", parsed.error.message, false);
    const { nodeId, markCompleted } = parsed.data;
    const db = (0, firestore_1.getFirestore)();
    const now = new Date();
    const nowISO = now.toISOString();
    await db.runTransaction(async (tx) => {
        const ref = db.collection("activities").doc(nodeId);
        const snap = await tx.get(ref);
        if (!snap.exists)
            throw new Error("NOT_FOUND");
        const a = snap.data();
        if (a.userId !== uid)
            throw new Error("PERMISSION_DENIED");
        const startedAt = a.started_at ? new Date(a.started_at) : null;
        const delta = startedAt ? Math.max(0, Math.floor((now.getTime() - startedAt.getTime()) / 1000)) : 0;
        const total = (a.total_seconds ?? 0) + delta;
        tx.update(ref, {
            status: markCompleted ? ACTIVITY_STATUS.completed : ACTIVITY_STATUS.idle,
            started_at: null,
            total_seconds: total,
            updated_at: nowISO,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
    });
    return (0, envelope_1.ok)({ nodeId, status: markCompleted ? ACTIVITY_STATUS.completed : ACTIVITY_STATUS.idle });
}
//# sourceMappingURL=activity_tools.js.map