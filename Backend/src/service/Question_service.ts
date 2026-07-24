import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { Question } from "../models/Questions.js";

// ── client-safe question shape ──────────────────────────────────────────────
// What we broadcast *before* everyone has answered: no `correct` flag on the
// choices, and no `explanation` — both would give the answer away. The full
// Question (with `correct`/`explanation`) never leaves the server until the
// reveal, which is sent separately once every player has answered.
export interface PublicChoice {
    id: number;
    text: string;
}
export interface PublicQuestion {
    id: number;
    chapter: number;
    subject: string;
    question: string;
    choices: PublicChoice[];
}

export function toPublicQuestion(question: Question): PublicQuestion {
    return {
        id: question.id,
        chapter: question.chapter,
        subject: question.subject,
        question: question.question,
        // Shuffle display order so the correct choice isn't always in the
        // same position (the data files always list it first). Choice `id`
        // travels with each choice, so answer submission/reveal still work
        // by id regardless of display order.
        choices: shuffle(question.choices).map(({ id, text }) => ({ id, text })),
    };
}

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// src/service/Question_service.ts -> ../data/questions
const QUESTIONS_DIR = path.join(__dirname, "..", "data", "questions");

export const QUESTIONS_PER_GAME = 10;

// A game with fewer than this many questions isn't really worth playing —
// configureQuiz() rejects a selection that can't reach this.
export const MIN_QUESTIONS_PER_GAME = 4;

export interface SubjectInfo {
    subject: string;
    chapters: number[]; // sorted, e.g. [1, 2, 3]
    questionCount: number; // total questions across every chapter of this subject
}

interface ChapterFileEntry {
    subject: string;
    chapter: number;
    filePath: string;
}

// ── directory scan (done once at startup) ───────────────────────────────────

function scanChapterFiles(): ChapterFileEntry[] {
    if (!fs.existsSync(QUESTIONS_DIR)) {
        console.warn(`Questions directory not found: ${QUESTIONS_DIR}`);
        return [];
    }

    const entries: ChapterFileEntry[] = [];
    const subjectDirs = fs
        .readdirSync(QUESTIONS_DIR, { withFileTypes: true })
        .filter(d => d.isDirectory());

    for (const subjectDir of subjectDirs) {
        const subject = subjectDir.name;
        const subjectPath = path.join(QUESTIONS_DIR, subject);

        const files = fs
            .readdirSync(subjectPath)
            .filter(f => /^chapter_\d+\.json$/i.test(f));

        for (const file of files) {
            const match = file.match(/^chapter_(\d+)\.json$/i);
            const chapter = match ? Number(match[1]) : NaN;
            if (Number.isNaN(chapter)) continue;

            entries.push({
                subject,
                chapter,
                filePath: path.join(subjectPath, file),
            });
        }
    }

    return entries;
}

const chapterFiles: ChapterFileEntry[] = scanChapterFiles();

// Cache parsed chapter contents so repeated room configuration doesn't hit
// the filesystem on every request.
const chapterCache = new Map<string, Question[]>();

function cacheKey(subject: string, chapter: number): string {
    return `${subject}::${chapter}`;
}

function loadChapter(subject: string, chapter: number): Question[] {
    const key = cacheKey(subject, chapter);
    const cached = chapterCache.get(key);
    if (cached) return cached;

    const entry = chapterFiles.find(
        f => f.subject === subject && f.chapter === chapter
    );
    if (!entry) return [];

    try {
        const raw = fs.readFileSync(entry.filePath, "utf-8");
        const parsed: Question[] = JSON.parse(raw);
        chapterCache.set(key, parsed);
        return parsed;
    } catch (err) {
        console.error(`Failed to load ${entry.filePath}:`, err);
        return [];
    }
}

// ── public API ───────────────────────────────────────────────────────────────

// Returns every subject with its available chapters and question counts, so
// the host's UI can render subject/chapter pickers.
export function getAvailableSubjects(): SubjectInfo[] {
    const bySubject = new Map<string, number[]>();

    for (const { subject, chapter } of chapterFiles) {
        const list = bySubject.get(subject) ?? [];
        list.push(chapter);
        bySubject.set(subject, list);
    }

    return Array.from(bySubject.entries())
        .map(([subject, chapters]) => {
            const sortedChapters = [...chapters].sort((a, b) => a - b);
            const questionCount = sortedChapters.reduce(
                (sum, chapter) => sum + loadChapter(subject, chapter).length,
                0
            );
            return { subject, chapters: sortedChapters, questionCount };
        })
        .sort((a, b) => a.subject.localeCompare(b.subject));
}

export function isValidSubject(subject: string): boolean {
    return chapterFiles.some(f => f.subject === subject);
}

// Chapters that actually exist for a subject, out of the ones requested.
export function filterValidChapters(subject: string, chapters: number[]): number[] {
    const validChapters = new Set(
        chapterFiles.filter(f => f.subject === subject).map(f => f.chapter)
    );
    return chapters.filter(c => validChapters.has(c));
}

export function shuffle<T>(array: T[]): T[] {
    const copy = [...array];
    for (let i = copy.length - 1; i > 0; i--) {
        const randomIndex = Math.floor(Math.random() * (i + 1));
        [copy[i], copy[randomIndex]] = [copy[randomIndex]!, copy[i]!];
    }
    return copy;
}


export function getQuestionsBySelection(
    subject: string,
    chapters: number[]
): Question[] {
    const validChapters = filterValidChapters(subject, chapters);
    const merged = validChapters.flatMap(chapter => loadChapter(subject, chapter));
    const shuffled = shuffle(merged);
    return shuffled.slice(0, QUESTIONS_PER_GAME);
}