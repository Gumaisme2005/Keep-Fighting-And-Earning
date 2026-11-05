#!/usr/bin/env python3
"""Check repository Markdown images without network access or third party packages.

Supports inline/reference Markdown images, HTML img src and inline document links. Checks local paths
case-sensitively, including root-relative and URL-encoded paths. HTTP(S) badges
are listed separately, not treated as verified. Default mode writes no files.
"""
from __future__ import annotations

import argparse
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import posixpath
import re
import struct
from urllib.parse import unquote, urlsplit
import zlib

ROOT = Path(__file__).resolve().parents[1]
IGNORED = {'.git', '.godot', '.godot-test-results', '__pycache__', '_cov', '_mutant', 'build'}
IMAGE_SUFFIXES = {'.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp', '.avif'}
INLINE_IMAGE = re.compile(r'!\[([^\]]*)\]\(\s*(<[^>]+>|(?:\\.|[^\s()]|\([^()]*\))+)(?:\s+[^\n)]*)?\s*\)')
REFERENCE_IMAGE = re.compile(r'!\[([^\]]*)\](?:\[([^\]]*)\])?(?!\()')
REFERENCE_DEF = re.compile(r'^ {0,3}\[([^\]]+)\]:\s*(<[^>]+>|\S+)', re.M)
INLINE_LINK = re.compile(r'\]\(\s*(<[^>]+>|(?:\\.|[^\s()]|\([^()]*\))+)(?:\s+[^\n)]*)?\s*\)')


def blank(text: str) -> str:
    return ''.join('\n' if c == '\n' else ' ' for c in text)


def visible_markdown(text: str) -> str:
    """Keep offsets/line numbers while ignoring examples and HTML comments."""
    lines = []
    fence = None
    for line in text.splitlines(keepends=True):
        match = re.match(r'^ {0,3}(`{3,}|~{3,})', line)
        if fence:
            lines.append(blank(line))
            if match and match[1][0] == fence[0] and len(match[1]) >= len(fence):
                fence = None
        elif match:
            fence = match[1]
            lines.append(blank(line))
        else:
            lines.append(line)
    result = re.sub(r'<!--.*?-->', lambda m: blank(m[0]), ''.join(lines), flags=re.S)
    return re.sub(r'(`+)(.*?)\1', lambda m: blank(m[0]), result)


class HTMLImages(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.images: list[tuple[str, str, int]] = []

    def handle_starttag(self, tag: str, attrs: list) -> None:
        if tag.lower() == 'img':
            values = dict(attrs)
            self.images.append((values.get('src') or '', values.get('alt') or '', self.getpos()[0]))


def image_references(text: str) -> list[tuple[str, str, int]]:
    visible = visible_markdown(text)
    refs = []
    definitions = {re.sub(r'\s+', ' ', m[1]).strip().casefold(): m[2].strip('<>')
                   for m in REFERENCE_DEF.finditer(visible)}
    for match in INLINE_IMAGE.finditer(visible):
        refs.append((match[2].strip('<>'), match[1], visible[:match.start()].count('\n') + 1))
    # Remove inline forms before resolving reference-style and shortcut images.
    remainder = INLINE_IMAGE.sub(lambda m: blank(m[0]), visible)
    for match in REFERENCE_IMAGE.finditer(remainder):
        label = re.sub(r'\s+', ' ', match[2] or match[1]).strip().casefold()
        refs.append((definitions.get(label, ''), match[1], remainder[:match.start()].count('\n') + 1))
    parser = HTMLImages()
    parser.feed(visible)
    refs.extend(parser.images)
    return refs


def png_info(data: bytes) -> dict:
    """Validate PNG chunks/CRC and compressed image data, without changing pixels."""
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('Invalid PNG signature')
    offset = 8
    compressed = bytearray()
    dimensions = None
    while offset + 12 <= len(data):
        length = struct.unpack('>I', data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        end = offset + 12 + length
        if end > len(data):
            raise ValueError('Truncated PNG chunk')
        payload = data[offset + 8:end - 4]
        crc = struct.unpack('>I', data[end - 4:end])[0]
        if zlib.crc32(kind + payload) & 0xffffffff != crc:
            raise ValueError('PNG CRC mismatch')
        if kind == b'IHDR':
            dimensions = struct.unpack('>II', payload[:8])
            if not all(dimensions):
                raise ValueError('Empty PNG dimensions')
        elif kind == b'IDAT':
            compressed.extend(payload)
        elif kind == b'IEND':
            if not dimensions or not compressed:
                raise ValueError('Missing PNG header/image data')
            zlib.decompress(compressed)
            return {'width': dimensions[0], 'height': dimensions[1], 'validation': 'PNG CRC and decompression OK'}
        offset = end
    raise ValueError('Missing PNG end chunk')


def check(root: Path) -> dict:
    root = root.resolve()
    files = {p.relative_to(root).as_posix(): p for p in root.rglob('*')
             if p.is_file() and not IGNORED.intersection(p.relative_to(root).parts)}
    local = []
    document_links = []
    external = []
    errors = []
    warnings = []
    markdown = sorted(name for name in files if name.lower().endswith('.md'))
    for name in markdown:
        source = files[name].read_text(encoding='utf-8-sig')
        visible = visible_markdown(source)
        for match in INLINE_LINK.finditer(visible):
            # Find the matching '[' so nested badge links are checked, while the
            # embedded ![image](...) is handled by the image validator below.
            opening, depth = match.start(), 1
            while opening > 0 and depth:
                opening -= 1
                if visible[opening] == ']':
                    depth += 1
                elif visible[opening] == '[':
                    depth -= 1
            if opening > 0 and visible[opening - 1] == '!':
                continue
            target = match[1].strip('<>')
            parsed = urlsplit(target)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            decoded = unquote(parsed.path)
            relative = posixpath.normpath(decoded.lstrip('/') if decoded.startswith('/')
                                         else posixpath.join(posixpath.dirname(name), decoded))
            line = source[:match.start()].count('\n') + 1
            if '\\' in decoded or relative == '..' or relative.startswith('../'):
                errors.append(f'{name}:{line}: invalid repository link: {target}')
            elif relative not in files and not any(p.startswith(relative.rstrip('/') + '/') for p in files):
                errors.append(f'{name}:{line}: missing or case-mismatched document link: {target}')
            else:
                document_links.append({'source': name, 'line': line, 'target': target, 'resolved': relative})
        for target, alt, line in image_references(source):
            ref = {'source': name, 'line': line, 'target': target, 'alt': alt}
            parsed = urlsplit(target)
            if parsed.scheme in {'https', 'http'} or parsed.netloc:
                external.append({**ref, 'verified': False})
                continue
            if parsed.scheme or not parsed.path:
                errors.append(f'{name}:{line}: unsupported or missing image source: {target!r}')
                continue
            decoded = re.sub(r'\\([ ()])', r'\1', unquote(parsed.path))
            if '\\' in decoded:
                errors.append(f'{name}:{line}: use forward slashes in GitHub image paths: {target}')
                continue
            # Normalize lexically: Path.resolve() corrects case on Windows, hiding
            # links that would break on GitHub/Linux.
            relative = posixpath.normpath(decoded.lstrip('/') if decoded.startswith('/')
                                         else posixpath.join(posixpath.dirname(name), decoded))
            if relative == '..' or relative.startswith('../'):
                errors.append(f'{name}:{line}: image outside repository: {target}')
                continue
            if relative not in files:
                errors.append(f'{name}:{line}: missing or case-mismatched image: {target}')
                continue
            if not files[relative].resolve().is_relative_to(root):
                errors.append(f'{name}:{line}: image symlink outside repository: {target}')
                continue
            if files[relative].suffix.lower() not in IMAGE_SUFFIXES:
                errors.append(f'{name}:{line}: unsupported image format: {target}')
                continue
            if not alt.strip():
                warnings.append(f'{name}:{line}: image has no alt text')
            local.append({**ref, 'resolved': relative})
    images = {}
    documentation_images = {name for name in files if name.startswith(('docs/', 'benchmarks/reports/'))
                            and Path(name).suffix.lower() in IMAGE_SUFFIXES}
    referenced = {ref['resolved'] for ref in local}
    for name in sorted(documentation_images | referenced):
        data = files[name].read_bytes()
        info = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
                'references': [ref for ref in local if ref['resolved'] == name]}
        try:
            if name.lower().endswith('.png'):
                info.update(png_info(data))
            else:
                info['validation'] = 'Path and checksum only; image decoding not checked'
        except (ValueError, struct.error, zlib.error) as exc:
            errors.append(f'{name}: {exc}')
        images[name] = info
    return {'markdown_files_checked': len(markdown), 'local_image_references': local,
            'local_document_links': document_links,
            'external_image_references_not_fetched': external, 'images': images,
            'unreferenced_documentation_images': sorted(documentation_images - referenced),
            'errors': errors, 'warnings': warnings,
            'scope': 'Static local file/directory link and image/case checks and PNG integrity; heading fragments, GitHub rendering and external URL availability are not checked.'}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--json', type=Path, help='Explicitly save the check result')
    args = parser.parse_args()
    result = check(args.root)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    for error in result['errors']:
        print('ERROR:', error)
    for warning in result['warnings']:
        print('WARNING:', warning)
    print(f"Markdown: {result['markdown_files_checked']}; local image references: "
          f"{len(result['local_image_references'])}; images: {len(result['images'])}; "
          f"document links: {len(result['local_document_links'])}; "
          f"errors: {len(result['errors'])}; warnings: {len(result['warnings'])}")
    print(f"External images not fetched: {len(result['external_image_references_not_fetched'])}")
    return int(bool(result['errors']))


if __name__ == '__main__':
    raise SystemExit(main())
