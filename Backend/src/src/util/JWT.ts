import jwt from "jsonwebtoken";
import dotenv from "dotenv";
import type { User, JwtPayload } from "../models/User.js";

dotenv.config();

const secret = process.env.JWT_SECRET as string;

export const generateToken = (user: User): string => {
  const payload: JwtPayload = {
    id: user.id,
    userName: user.userName,
  };

  return jwt.sign(payload, secret, {
    expiresIn: "1h",
  });
};
