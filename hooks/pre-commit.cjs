#!/usr/bin/env node
/**
 * A pure Koru program belongs in a `.k` file.
 *
 * `~` is a PARSER SWITCH. It exists so a file that contains a host language can
 * say "this line is Koru, not that". A file with no host language in it has
 * nothing to switch out of, so every `~` in it is noise — and worse, it is noise
 * that ends up in blog posts and documentation, where it reads as though Koru's
 * syntax requires a sigil on every declaration. It does not.
 *
 * This gate exists because the question "why is our code not pure Koru?" has
 * been asked repeatedly, answered each time by fixing one file, and then asked
 * again about the next one. Fixing an instance does not stop the next instance.
 *
 * It refuses two things:
 *
 *   1. A `.kz` file with NO host content — it should be `.k`, untilded.
 *   2. A `.k` file containing a leading `~` — there is nothing to switch out of.
 *
 * Host content means the file genuinely mixes in another language: an import of
 * a host module, an extern declaration, a host type or function at top level.
 * Those files keep their `.kz` and their tildes, which is what the tilde is for.
 *
 * Override, for the case where the heuristic is wrong rather than the file:
 *
 *   KZ_HAS_HOST_CODE=1 git commit ...
 */

const { execFileSync } = require('node:child_process');

function git(args, opts = {}) {
	return execFileSync('git', args, { encoding: 'utf8', ...opts });
}

function staged() {
	return git(['diff', '--cached', '--name-only', '--diff-filter=ACM'])
		.split('\n')
		.filter(Boolean);
}

function content(path) {
	return git(['show', `:${path}`]);
}

/** Strip comments and string literals so their contents cannot vote. */
function code(text) {
	return text
		.split('\n')
		.filter((l) => !/^\s*\/\//.test(l))
		.join('\n')
		.replace(/"(?:[^"\\]|\\.)*"/g, '""');
}

/**
 * Does this file genuinely contain another language?
 *
 * Deliberately conservative: a file is only called "host" on evidence that is
 * hard to produce by accident. Data blocks (`std/build:config { ... }`) are NOT
 * host content — they are Koru declarations that happen to have braces, and
 * treating them as host is what kept these files on `.kz` in the first place.
 */
function hasHostContent(text) {
	const c = code(text);
	return (
		/@import\s*\(/.test(c) ||
		/@extern\s*\(/.test(c) ||
		/@cImport/.test(c) ||
		/\bextern\s+fn\b/.test(c) ||
		/^\s*(pub\s+)?fn\s+\w/m.test(c) ||
		/^\s*(pub\s+)?const\s+\w+\s*(:[^=]+)?=/m.test(c) ||
		/^\s*(pub\s+)?var\s+\w+\s*:/m.test(c) ||
		/^\s*threadlocal\s/m.test(c)
	);
}

/** A leading `~` on a declaration — the parser switch, not a path or a string. */
function leadingTildes(text) {
	return text
		.split('\n')
		.map((line, i) => ({ line, n: i + 1 }))
		.filter(({ line }) => !/^\s*\/\//.test(line))
		.filter(({ line }) => /^\s*(\[[^\]]*\])?~/.test(line));
}

const problems = [];

for (const path of staged()) {
	if (path.endsWith('.kz')) {
		const text = content(path);
		if (!hasHostContent(text)) {
			problems.push({
				path,
				why: 'a .kz file with no host language in it',
				fix: `git mv ${path} ${path.slice(0, -3)}.k   and delete the leading ~ from every declaration`
			});
		}
	} else if (path.endsWith('.k')) {
		const hits = leadingTildes(content(path));
		if (hits.length) {
			problems.push({
				path,
				why: `${hits.length} leading \`~\` in a pure Koru file (first at line ${hits[0].n})`,
				fix: 'delete them — there is no host language here to switch out of'
			});
		}
	}
}

if (!problems.length) process.exit(0);

if (process.env.KZ_HAS_HOST_CODE === '1') {
	console.error(`\n  Allowing ${problems.length} file(s) — KZ_HAS_HOST_CODE=1 was set.\n`);
	process.exit(0);
}

console.error(`
┌───────────────────────────────────────────────────────────────────────────┐
│  REFUSED: Koru that is pure should look pure                              │
└───────────────────────────────────────────────────────────────────────────┘

  \`~\` is a parser switch for files that mix in another language. A file with
  no other language in it has nothing to switch out of, and every \`~\` in it
  is noise that ends up quoted in posts and docs as though the language
  required it.
`);

for (const p of problems) {
	console.error(`  ✗ ${p.path}`);
	console.error(`      ${p.why}`);
	console.error(`      fix: ${p.fix}\n`);
}

console.error(`  If the file really does contain host code and this missed it, say so:

      KZ_HAS_HOST_CODE=1 git commit ...

  and please widen hasHostContent() in hooks/pre-commit.cjs so the next one
  is caught rather than waved through.
`);

process.exit(1);
