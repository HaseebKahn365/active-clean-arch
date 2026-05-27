import { z } from "zod";

export const activityDocSchema = z.object({
  userId: z.string().min(1),
  id: z.string().min(1),
  name: z.string().min(1),
  description: z.string().optional().nullable(),
  parent_id: z.string().optional().nullable(),
  children_ids: z.string().default("[]"), // JSON-encoded string list
  status: z.string().min(1),
  started_at: z.string().optional().nullable(),
  total_seconds: z.number().int().nonnegative(),
  goal_seconds: z.number().int().nonnegative().optional().default(0),
  type: z.string().min(1),
  is_pinned: z.number().int().optional().default(0),
  created_at: z.string().min(1),
  updated_at: z.string().min(1),
  updatedAt: z.any().optional()
});

export type ActivityDoc = z.infer<typeof activityDocSchema>;

export function parseChildrenIds(children_ids: string | undefined | null): string[] {
  if (!children_ids) return [];
  try {
    const parsed = JSON.parse(children_ids);
    if (Array.isArray(parsed)) return parsed.filter((x) => typeof x === "string");
    return [];
  } catch {
    return [];
  }
}

export function serializeChildrenIds(ids: string[]): string {
  return JSON.stringify(ids);
}

