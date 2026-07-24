export interface User {
  id: number;
  userName: string;
  password: string;
  score: number; // cumulative score across every finished game
}

export interface JwtPayload {
  id: number;
  userName: string;
}
