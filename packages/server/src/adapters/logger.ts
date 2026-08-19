import { formatEvent, readLogLevel, type LogLevel } from "../log.js";

/**
 * The only thing in this package that writes to a stream.
 *
 * **ADAPTER.** It owns the clock and the destination; every decision about what
 * a line contains is in `../log.ts`, which is pure. `test/one-way-to-log.test.ts`
 * is what keeps that true — no other file under `src/` may call `console`.
 */
export interface Logger {
  readonly debug: (message: string, fields?: Readonly<Record<string, unknown>>) => void;
  readonly info: (message: string, fields?: Readonly<Record<string, unknown>>) => void;
  readonly warn: (message: string, fields?: Readonly<Record<string, unknown>>) => void;
  readonly error: (message: string, fields?: Readonly<Record<string, unknown>>) => void;
}

export interface LoggerOptions {
  readonly level: LogLevel;
  readonly write: (line: string) => void;
  readonly now: () => Date;
}

export function createLogger({ level, write, now }: LoggerOptions): Logger {
  const at =
    (eventLevel: LogLevel) =>
    (message: string, fields?: Readonly<Record<string, unknown>>): void => {
      const line = formatEvent(
        fields === undefined
          ? { level: eventLevel, message, at: now() }
          : { level: eventLevel, message, at: now(), fields },
        level,
      );
      if (line !== null) {
        write(line);
      }
    };

  return {
    debug: at("debug"),
    info: at("info"),
    warn: at("warn"),
    error: at("error"),
  };
}

/**
 * The process logger: `LOG_LEVEL` from the environment, lines to stdout.
 *
 * **One stream, including errors.** Splitting warn and error onto stderr
 * reorders them against everything else the moment the two are piped
 * separately, and the level is already in the line. A container runtime wants
 * one stream anyway.
 *
 * `process.stdout.write` rather than `console.log`, because `console.log`
 * appends a newline of its own and `formatEvent` already ended the line.
 */
export function createProcessLogger(env: Record<string, string | undefined>): Logger {
  const { level, ignored } = readLogLevel(env["LOG_LEVEL"]);
  const logger = createLogger({
    level,
    write: (line) => process.stdout.write(line),
    now: () => new Date(),
  });
  if (ignored !== undefined) {
    logger.warn("LOG_LEVEL was not recognised; using the default", {
      ignored,
      using: level,
    });
  }
  return logger;
}
