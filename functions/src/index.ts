import { initializeApp } from "firebase-admin/app";
import { onCall } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { v4 as uuidv4 } from "uuid";

import * as activityTools from "./tools/activity_tools";
import * as analyticsTools from "./tools/analytics_tools";
import { err, type ToolEnvelope } from "./shared/envelope";

initializeApp();
const db = getFirestore();

function wrap<TInput>(
  toolName: string,
  handler: (uid: string | undefined, input: TInput) => Promise<ToolEnvelope>,
) {
  return onCall({ cors: true }, async (request): Promise<ToolEnvelope> => {
    const uid = request.auth?.uid;
    const auditId = uuidv4();
    const startedAt = Date.now();
    try {
      const result = await handler(uid, request.data as TInput);
      const withAudit = { ...result, auditId };
      await db.collection("ai_tool_audits").add({
        auditId,
        toolName,
        uid: uid ?? null,
        ok: (result as any).ok === true,
        ts: new Date().toISOString(),
        durationMs: Date.now() - startedAt,
      });
      return withAudit;
    } catch (e: any) {
      let out: ToolEnvelope;
      if (e?.message === "PERMISSION_DENIED") out = err("PERMISSION_DENIED", "Not allowed.", false);
      else if (e?.message === "NOT_FOUND") out = err("NOT_FOUND", "Not found.", false);
      else if (e?.message === "NEW_PARENT_NOT_FOUND") out = err("NOT_FOUND", "New parent not found.", false);
      else if (e?.message === "HAS_CHILDREN") {
        out = err("FAILED_PRECONDITION", "Cannot delete a node that has children. Move or delete children first.", false);
      } else if (e?.message === "CYCLE") out = err("FAILED_PRECONDITION", "Move would create a cycle.", false);
      else out = err("INTERNAL", typeof e?.message === "string" ? e.message : "Unknown error", true);

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

// State inspection
export const getTreeSnapshot = wrap("getTreeSnapshot", activityTools.getTreeSnapshot);
export const getActivityNamesYaml = wrap("getActivityNamesYaml", activityTools.getActivityNamesYaml);
export const getRunningActivities = wrap("getRunningActivities", activityTools.getRunningActivities);
export const getNode = wrap("getNode", activityTools.getNode);
export const searchNodes = wrap("searchNodes", activityTools.searchNodes);
export const addCount = wrap("addCount", activityTools.addCount);
export const getActivityTotal = wrap("getActivityTotal", activityTools.getActivityTotal);
export const getBreadcrumbs = wrap("getBreadcrumbs", activityTools.getBreadcrumbs);
export const togglePin = wrap("togglePin", activityTools.togglePin);
export const updateActivityDuration = wrap("updateActivityDuration", activityTools.updateActivityDuration);
export const checkpointActivity = wrap("checkpointActivity", activityTools.checkpointActivity);
export const completeActivity = wrap("completeActivity", activityTools.completeActivity);
export const clearAllData = wrap("clearAllData", activityTools.clearAllData);

// Mutations
export const createNode = wrap("createNode", activityTools.createNode);
export const updateNode = wrap("updateNode", activityTools.updateNode);
export const moveNode = wrap("moveNode", activityTools.moveNode);
export const deleteNode = wrap("deleteNode", activityTools.deleteNode);

// Run control
export const startActivity = wrap("startActivity", activityTools.startActivity);
export const pauseActivity = wrap("pauseActivity", activityTools.pauseActivity);
export const stopActivity = wrap("stopActivity", activityTools.stopActivity);

// Analytics
export const getAnalytics = wrap("getAnalytics", analyticsTools.getAnalytics);

