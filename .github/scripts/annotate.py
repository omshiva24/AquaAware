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


PROJECT_LOCATION = re.compile(r'(?:AquaAware/(?:lib|test)/|package:aquaaware/)[^\s)]+\.dart:\d+(?::\d+)?')


def traced_errors(lines):
    """Compact summary of errors the smoke test prints the moment they happen
    (AQUA-ERROR-BEGIN … END), each with the screen being visited and the
    project file and line that caused it. Shown first, so nothing is cut off."""
    out, seen = [], set()
    visit, block = '', None
    for line in lines:
        if 'AQUA-VISIT ' in line:
            visit = line.split('AQUA-VISIT ', 1)[1].strip()
        elif 'AQUA-ERROR-BEGIN' in line:
            block = []
        elif 'AQUA-ERROR-END' in line and block is not None:
            text = [l.strip() for l in block if l.strip()]
            summary = next((l for l in text if not l.startswith(('══', '#'))
                            and 'was thrown' not in l and 'EXCEPTION CAUGHT' not in l), '?')
            places = []
            for l in text:
                for m in PROJECT_LOCATION.findall(l):
                    loc = m.split('AquaAware/', 1)[-1]
                    if loc not in places:
                        places.append(loc)
            constraints = next((l for l in text if l.startswith('constraints:')), '')
            entry = f'{visit or "(setup)"}: {summary}'
            if places:
                entry += '\n    at ' + '\n    at '.join(places[:4])
            if constraints:
                entry += '\n    ' + constraints
            key = (summary, tuple(places[:2]))
            if key not in seen:
                seen.add(key)
                out.append(entry)
            block = None
        elif block is not None:
            block.append(line)
    return ['Errors as they happened (screen: error, then where):\n\n' + '\n\n'.join(out)] if out else []


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
    found = (traced_errors(lines) + test_failures(lines) + exception_blocks(lines)) if mode == 'tests' else error_lines(lines)
    if not found:
        found = ['\n'.join(lines[-120:])]
    parts = chunk(found)
    for n, part in enumerate(parts[:MAX_ANNOTATIONS], 1):
        emit(f'{label} ({n}/{min(len(parts), MAX_ANNOTATIONS)})', part)


if __name__ == '__main__':
    main()
