export const Types = {
    JOIN : "join",
    LEFET : "left",
    MESSAGE :  "message",
    ANSWER : "answer"
}as const 
export type Types = typeof Types[keyof typeof Types];