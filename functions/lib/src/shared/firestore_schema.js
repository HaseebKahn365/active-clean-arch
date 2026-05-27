"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.activityDocSchema = void 0;
exports.parseChildrenIds = parseChildrenIds;
exports.serializeChildrenIds = serializeChildrenIds;
const zod_1 = require("zod");
exports.activityDocSchema = zod_1.z.object({
    userId: zod_1.z.string().min(1),
    id: zod_1.z.string().min(1),
    name: zod_1.z.string().min(1),
    description: zod_1.z.string().optional().nullable(),
    parent_id: zod_1.z.string().optional().nullable(),
    children_ids: zod_1.z.string().default("[]"), // JSON-encoded string list
    status: zod_1.z.string().min(1),
    started_at: zod_1.z.string().optional().nullable(),
    total_seconds: zod_1.z.number().int().nonnegative(),
    goal_seconds: zod_1.z.number().int().nonnegative().optional().default(0),
    type: zod_1.z.string().min(1),
    is_pinned: zod_1.z.number().int().optional().default(0),
    created_at: zod_1.z.string().min(1),
    updated_at: zod_1.z.string().min(1),
    updatedAt: zod_1.z.any().optional()
});
function parseChildrenIds(children_ids) {
    if (!children_ids)
        return [];
    try {
        const parsed = JSON.parse(children_ids);
        if (Array.isArray(parsed))
            return parsed.filter((x) => typeof x === "string");
        return [];
    }
    catch {
        return [];
    }
}
function serializeChildrenIds(ids) {
    return JSON.stringify(ids);
}
//# sourceMappingURL=firestore_schema.js.map