import jwt from "jsonwebtoken";
import dotenv from "dotenv";
import type { Request, Response, NextFunction } from "express";
import type { JwtPayload } from "../types/User.js";

dotenv.config();

const secret = process.env.JWT_SECRET as string;

export const authentication = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const header = req.headers.authorization;
  if (!header) {
    res.status(400).json({
      message: "No token",
    });
    return;
  }
  const token = header.split(" ")[1];
  if (!token) {
    res.status(400).json({
      message: "No token",
    });
    return;
  }
  try {
    const decoded = jwt.verify(token, secret) as JwtPayload;
    req.user = decoded;
    next();
  } catch (e) {
    const message = e instanceof Error ? e.message : "Unknown error";
    res.status(500).json({
      message,
    });
  }
};
