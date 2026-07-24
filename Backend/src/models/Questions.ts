export interface Choice {
    id: number;
    text: string;
    correct: boolean;
}
export interface Question {
    id: number;
    chapter: number;
    subject: string;
    question: string;
    choices: Choice[];
    explanation: string;
} 