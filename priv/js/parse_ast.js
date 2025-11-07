#!/usr/bin/env node
"use strict";

const fs = require("fs");

async function main() {
  let input;
  const envPayload = process.env.PLED_AST_PAYLOAD;

  if (envPayload) {
    try {
      input = JSON.parse(Buffer.from(envPayload, "base64").toString("utf8"));
    } catch (err) {
      return emit({ ok: false, error: "invalid_input", message: err.message });
    }
  } else {
    const stdin = await readStdin();

    try {
      input = JSON.parse(stdin || "{}");
    } catch (err) {
      return emit({ ok: false, error: "invalid_input", message: err.message });
    }
  }

  const code = typeof input.code === "string" ? input.code : "";
  const sourceType = input.module ? "module" : "script";

  let acorn;
  try {
    acorn = require("acorn");
  } catch (err) {
    return emit({
      ok: false,
      error: "dependency_missing",
      message: "Install JS parser dependencies in priv/js (npm install)",
      details: { module: "acorn", original: err.message }
    });
  }

  const options = {
    ecmaVersion: "latest",
    allowHashBang: true,
    sourceType,
    locations: true
  };

  const program = tryParseProgram(acorn, code, options);

  if (program.ok) {
    return emit({ ok: true, ast: sanitize(program.ast), meta: program.meta });
  }

  const expression = tryParseExpression(acorn, code, options);

  if (expression.ok) {
    return emit({ ok: true, ast: sanitize(expression.ast), meta: expression.meta });
  }

  emit(expression.error);
}

function readStdin() {
  return new Promise((resolve, reject) => {
    const chunks = [];
    process.stdin.on("data", (chunk) => chunks.push(chunk));
    process.stdin.on("error", reject);
    process.stdin.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
  });
}

function emit(payload) {
  process.stdout.write(JSON.stringify(payload));
}

main().catch((err) => {
  emit({ ok: false, error: "fatal", message: err.message });
});

function tryParseProgram(acorn, code, options) {
  try {
    const ast = acorn.parse(code, options);
    return { ok: true, ast, meta: { mode: "program" } };
  } catch (err) {
    return {
      ok: false,
      error: {
        ok: false,
        error: "parse_error",
        message: err.message,
        details: err.loc ? { line: err.loc.line, column: err.loc.column } : {}
      }
    };
  }
}

function tryParseExpression(acorn, code, options) {
  const wrapped = `(${code}\n)`;
  try {
    const ast = acorn.parse(wrapped, options);

    const expression =
      ast &&
      ast.body &&
      ast.body.length === 1 &&
      ast.body[0].type === "ExpressionStatement"
        ? ast.body[0].expression
        : ast;

    return { ok: true, ast: expression, meta: { mode: "expression" } };
  } catch (err) {
    return {
      ok: false,
      error: {
        ok: false,
        error: "parse_error",
        message: err.message,
        details: err.loc ? { line: err.loc.line, column: err.loc.column } : {}
      }
    };
  }
}

function sanitize(node) {
  if (!node || typeof node !== "object") {
    return node;
  }

  if (Array.isArray(node)) {
    return node.map((item) => sanitize(item));
  }

  const clean = {};

  for (const [key, value] of Object.entries(node)) {
    if (key === "start" || key === "end" || key === "loc") {
      continue;
    }

    clean[key] = sanitize(value);
  }

  return clean;
}
