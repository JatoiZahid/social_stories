"""Normalize/copy story JSON while retaining authored scenes, quizzes and metadata.

assets/data/stories.json is the source of truth. The former generator recreated
static crops and silently discarded scene animations and parent-authored quizzes.
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--source', type=Path, help='Explicit source; defaults to existing output or bundled story data')
    args = parser.parse_args()
    source = args.source or (args.output if args.output.exists() else ROOT / 'assets/data/stories.json')
    data = json.loads(source.read_text(encoding='utf-8'))
    stories = data.get('stories')
    if not isinstance(stories, list) or any(not story.get('pages') for story in stories):
        raise ValueError('Expected stories with at least one page each')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(f'Preserved {len(stories)} stories and all authored fields in {args.output}')


if __name__ == '__main__':
    main()
