import type { JwtPayload } from "../models/User.js"; // FIX: was "./index.js" — there's no index.ts exporting JwtPayload; it lives in models/User.ts

declare global {
  namespace Express {
    interface Request {
      user?: JwtPayload;
    }
  }
}

export {};