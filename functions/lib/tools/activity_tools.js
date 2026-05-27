"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getTreeSnapshot = getTreeSnapshot;
exports.getRunningActivities = getRunningActivities;
exports.getNode = getNode;
exports.searchNodes = searchNodes;
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