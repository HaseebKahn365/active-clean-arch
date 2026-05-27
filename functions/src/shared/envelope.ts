export type ToolError = {
  code: string;
  message: string;
  retryable: boolean;
};

export type ToolEnvelope<T extends Record<string, unknown> = Record<string, unknown>> =
  | { ok: true; data: T; auditId?: string }
  | { ok: false; error: ToolError; auditId?: string };

export function ok<T extends Record<string, unknown>>(data: T, auditId?: string): ToolEnvelope<T> {
  return { ok: true, data, auditId };
}

export function err(code: string, message: string, retryable: boolean, auditId?: string): ToolEnvelope {
  return { ok: false, error: { code, message, retryable }, auditId };
}

