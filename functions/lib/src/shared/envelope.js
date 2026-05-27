"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ok = ok;
exports.err = err;
function ok(data, auditId) {
    return { ok: true, data, auditId };
}
function err(code, message, retryable, auditId) {
    return { ok: false, error: { code, message, retryable }, auditId };
}
//# sourceMappingURL=envelope.js.map