import type { Request, Response } from "express";
import { pool } from "../config/db.js";
import bcrypt from "bcrypt";
import { generateToken } from "../util/JWT.js";
import type { User } from "../types/User.js";

interface AuthBody {
  userName: string;
  password: string;
}

export const signUp = async (
  req: Request<unknown, unknown, AuthBody>,
  res: Response
): Promise<void> => {
  const { userName, password } = req.body;
  try {
    const userExist = await pool.query<User>(
      "SELECT * FROM users WHERE userName = $1",
      [userName]
    );
    if (userExist.rows.length > 0) {
      res.status(409).json({
        message: "This name is using",
      });
      return;
    }
    const hashPassword = await bcrypt.hash(password, 12);
    const newUser = await pool.query<User>(
      "INSERT INTO users (userName , password) VALUES ($1 , $2) RETURNING *",
      [userName, hashPassword]
    );
    res.status(201).json({
      message: "New user was created",
      user: newUser.rows[0],
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Unknown error";
    res.status(500).json({ message });
  }
};

export const signIn = async (
  req: Request<unknown, unknown, AuthBody>,
  res: Response
): Promise<void> => {
  const { userName, password } = req.body;
  try {
    const result = await pool.query<User>(
      "SELECT * FROM users WHERE userName = $1",
      [userName]
    );
    const user = result.rows[0];
    if (!user) {
      res.status(404).json({
        message: "user don't found",
      });
      return;
    }
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      res.status(401).json({ message: "Incorrect password" });
      return;
    }
    const token = generateToken(user);
    res.status(200).json({
      message: "Login successful",
      token,
      user: {
        id: user.id,
        userName: user.userName 
      }
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Unknown error";
    res.status(500).json({ message });
  }
};

export const getUsers = async (_req: Request, res: Response): Promise<void> => {
  try {
    const result = await pool.query<User>("SELECT * FROM users");
    if (result) {
      res.json({
        message: "users is :",
        user: result.rows,
      });
    }
  } catch (e) {
    const message = e instanceof Error ? e.message : "Unknown error";
    res.status(500).json({ message });
  }
};
