"""Turns the important part of a failed step's output into GitHub annotations,
so failures are readable on the run's summary page (and through the API)
without opening the full log.

    python3 .github/scripts/annotate.py tests  test-output.txt
    python3 .github/scripts/annotate.py errors build-output.txt "Android build"
"""
import re
import sys

MAX_ANNOTATIONS = 9  # GitHub shows at most 10 error annotations per step
MAX_CHARS = 3500


def escape(text):
    return text.replace('%', '%25').replace('\r', '').replace('\n', '%0A')


def emit(title, body):
    print(f'::error title={escape(title)}::{escape(body)}')


def test_failures(lines):
    """Blocks that start at a failed test ('[E]') and run to the next test line."""
    blocks, current = [], None
    progress = re.compile(r'^\s*\d+:\d+ \+\d+')
    for line in lines:
        if progress.match(line):
            if current:
                blocks.append(current)
                current = None
            if '[E]' in line:
                current = [line.strip()]
            continue
        if current is not None and len(current) < 40:
            current.append(line.rstrip())
    if current:
        blocks.append(current)
    return ['\n'.join(b) for b in blocks]


def exception_blocks(lines):
    """Flutter's framed exception reports: '══╡ EXCEPTION CAUGHT BY … ╞══' to the closing rule."""
    blocks, current = [], None
    for line in lines:
        if 'EXCEPTION CAUGHT BY' in line:
            if current:
                blocks.append(current)
            current = [line.strip()]
            continue
        if current is not None:
            if line.startswith('════') and len(current) > 1:
                blocks.append(current)
                current = None
            elif len(current) < 30:
                current.append(line.rstrip())
    if current:
        blocks.append(current)
    # Same exception repeated (e.g. every frame): keep the first of each kind.
    seen, out = set(), []
    for b in blocks:
        key = '\n'.join(b[:4])
        if key not in seen:
            seen.add(key)
            out.append('\n'.join(b))
    return out


def error_lines(lines):
    """Compiler and tool errors with a little context."""
    hits = []
    pattern = re.compile(r'(error|Error:|ERROR|FAILURE|Exception|failed|Could not|not found)', re.I)
    for i, line in enumerate(lines):
        if pattern.search(line) and 'warning' not in line.lower():
            hits.append('\n'.join(l.rstrip() for l in lines[max(0, i - 2): i + 6]))
    # de-duplicate overlapping context
    seen, out = set(), []
    for h in hits:
        key = h[:200]
        if key not in seen:
            seen.add(key)
            out.append(h)
    return out


def chunk(texts):
    out, cur = [], ''
    for t in texts:
        piece = t[:MAX_CHARS]
        if len(cur) + len(piece) + 2 > MAX_CHARS and cur:
            out.append(cur)
            cur = ''
        cur += piece + '\n\n'
    if cur:
        out.append(cur)
    return out


def main():
    mode, path = sys.argv[1], sys.argv[2]
    label = sys.argv[3] if len(sys.argv) > 3 else ('Test failure' if mode == 'tests' else 'Build error')
    try:
        lines = open(path, encoding='utf-8', errors='replace').read().splitlines()
    except OSError as e:
        emit(label, f'Could not read {path}: {e}')
        return
    found = (exception_blocks(lines) + test_failures(lines)) if mode == 'tests' else error_lines(lines)
    if not found:
        found = ['\n'.join(lines[-120:])]
    parts = chunk(found)
    for n, part in enumerate(parts[:MAX_ANNOTATIONS], 1):
        emit(f'{label} ({n}/{min(len(parts), MAX_ANNOTATIONS)})', part)


if __name__ == '__main__':
    main()
