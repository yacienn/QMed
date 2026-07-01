export interface User {
  id: number;
  userName: string;
  password: string;
}

export interface JwtPayload {
  id: number;
  userName: string;
}
