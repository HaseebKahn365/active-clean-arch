"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.getAnalytics = exports.stopActivity = exports.pauseActivity = exports.startActivity = exports.deleteNode = exports.moveNode = exports.updateNode = exports.createNode = exports.clearAllData = exports.completeActivity = exports.checkpointActivity = exports.updateActivityDuration = exports.togglePin = exports.getBreadcrumbs = exports.getActivityTotal = exports.addCount = exports.searchNodes = exports.getNode = exports.getRunningActivities = exports.getActivityNamesYaml = exports.getTreeSnapshot = exports.abortAiSession = void 0;
const app_1 = require("firebase-admin/app");
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const uuid_1 = require("uuid");
const activityTools = __importStar(require("./tools/activity_tools"));
const analyticsTools = __importStar(require("./tools/analytics_tools"));
const envelope_1 = require("./shared/envelope");
(0, app_1.initializeApp)();
const db = (0, firestore_1.getFirestore)();
const SESSION_CONTROL_COLLECTION = "ai_session_controls";
function wrap(toolName, handler) {
    return (0, https_1.onCall)({ cors: true }, async (request) => {
        const uid = request.auth?.uid;
        const sessionId = typeof request.data?.sessionId === "string" ? request.data.sessionId : undefined;
        const auditId = (0, uuid_1.v4)();
        const startedAt = Date.now();
        try {
            if (uid && sessionId) {
                const ctrlSnap = await db.collection(SESSION_CONTROL_COLLECTION).doc(`${uid}:${sessionId}`).get();
                if (ctrlSnap.exists && ctrlSnap.data()?.aborted === true) {
                    const aborted = (0, envelope_1.err)("ABORTED", "AI session was halted by user.", false);
                    return { ...aborted, auditId };
                }
            }
            const result = await handler(uid, request.data);
            const withAudit = { ...result, auditId };
            await db.collection("ai_tool_audits").add({
                auditId,
                toolName,
                uid: uid ?? null,
                ok: result.ok === true,
                ts: new Date().toISOString(),
                durationMs: Date.now() - startedAt,
            });
            return withAudit;
        }
        catch (e) {
            let out;
            if (e?.message === "PERMISSION_DENIED")
                out = (0, envelope_1.err)("PERMISSION_DENIED", "Not allowed.", false);
            else if (e?.message === "NOT_FOUND")
                out = (0, envelope_1.err)("NOT_FOUND", "Not found.", false);
            else if (e?.message === "NEW_PARENT_NOT_FOUND")
                out = (0, envelope_1.err)("NOT_FOUND", "New parent not found.", false);
            else if (e?.message === "HAS_CHILDREN") {
                out = (0, envelope_1.err)("FAILED_PRECONDITION", "Cannot delete a node that has children. Move or delete children first.", false);
            }
            else if (e?.message === "CYCLE")
                out = (0, envelope_1.err)("FAILED_PRECONDITION", "Move would create a cycle.", false);
            else
                out = (0, envelope_1.err)("INTERNAL", typeof e?.message === "string" ? e.message : "Unknown error", true);
            const withAudit = { ...out, auditId };
            await db.collection("ai_tool_audits").add({
                auditId,
                toolName,
                uid: uid ?? null,
                ok: false,
                ts: new Date().toISOString(),
                durationMs: Date.now() - startedAt,
                error: typeof e?.message === "string" ? e.message : String(e),
            });
            return withAudit;
        }
    });
}
exports.abortAiSession = (0, https_1.onCall)({ cors: true }, async (request) => {
    const uid = request.auth?.uid;
    const sessionId = typeof request.data?.sessionId === "string" ? request.data.sessionId.trim() : "";
    if (!uid)
        return (0, envelope_1.err)("UNAUTHENTICATED", "Sign-in is required.", false);
    if (!sessionId)
        return (0, envelope_1.err)("INVALID_ARGUMENT", "sessionId is required.", false);
    await db.collection(SESSION_CONTROL_COLLECTION).doc(`${uid}:${sessionId}`).set({
        uid,
        sessionId,
        aborted: true,
        abortedAt: new Date().toISOString(),
    });
    return {
        ok: true,
        data: { sessionId, aborted: true },
    };
});
// State inspection
exports.getTreeSnapshot = wrap("getTreeSnapshot", activityTools.getTreeSnapshot);
exports.getActivityNamesYaml = wrap("getActivityNamesYaml", activityTools.getActivityNamesYaml);
exports.getRunningActivities = wrap("getRunningActivities", activityTools.getRunningActivities);
exports.getNode = wrap("getNode", activityTools.getNode);
exports.searchNodes = wrap("searchNodes", activityTools.searchNodes);
exports.addCount = wrap("addCount", activityTools.addCount);
exports.getActivityTotal = wrap("getActivityTotal", activityTools.getActivityTotal);
exports.getBreadcrumbs = wrap("getBreadcrumbs", activityTools.getBreadcrumbs);
exports.togglePin = wrap("togglePin", activityTools.togglePin);
exports.updateActivityDuration = wrap("updateActivityDuration", activityTools.updateActivityDuration);
exports.checkpointActivity = wrap("checkpointActivity", activityTools.checkpointActivity);
exports.completeActivity = wrap("completeActivity", activityTools.completeActivity);
exports.clearAllData = wrap("clearAllData", activityTools.clearAllData);
// Mutations
exports.createNode = wrap("createNode", activityTools.createNode);
exports.updateNode = wrap("updateNode", activityTools.updateNode);
exports.moveNode = wrap("moveNode", activityTools.moveNode);
exports.deleteNode = wrap("deleteNode", activityTools.deleteNode);
// Run control
exports.startActivity = wrap("startActivity", activityTools.startActivity);
exports.pauseActivity = wrap("pauseActivity", activityTools.pauseActivity);
exports.stopActivity = wrap("stopActivity", activityTools.stopActivity);
// Analytics
exports.getAnalytics = wrap("getAnalytics", analyticsTools.getAnalytics);
//# sourceMappingURL=index.js.map