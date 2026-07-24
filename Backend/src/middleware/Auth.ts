import jwt from "jsonwebtoken";
import dotenv from "dotenv";
import type { Request, Response, NextFunction } from "express";
import type { JwtPayload } from "../models/User.js"; 

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
    const decoded = jwt.verify(token, secret);
   
    if (typeof decoded === "string") {
      throw new Error("Unexpected token payload shape");
    }
    req.user = decoded as JwtPayload;
    next();
  } catch (e) {
    const message = e instanceof Error ? e.message : "Unknown error";
    
    res.status(401).json({
      message,
    });
  }
};