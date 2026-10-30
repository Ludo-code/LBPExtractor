#!/usr/bin/env python3
"""Test double for `pdftotext -bbox-layout` (poppler-utils).

Implements just enough of the CLI to serve tests/pdf fixtures:
    pdftotext -bbox-layout -enc UTF-8 FILE -

Emits XHTML with <page>/<block>/<line>/<word> elements, mirroring the real
poppler output that lbpextract parses. Words are grouped into lines the same
way PyMuPDF groups them (block_no, line_no).
"""
import sys
import xml.sax.saxutils as sx

import pymupdf


def parse_args(argv):
    positional = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "-enc":
            i += 2
            continue
        if a.startswith("-"):
            i += 1
            continue
        positional.append(a)
        i += 1
    if not positional:
        sys.stderr.write("pdftotext_mock: no input file\n")
        sys.exit(1)
    infile = positional[0]
    if len(positional) > 1 and positional[-1] != "-":
        outfile = positional[-1]
    else:
        outfile = None  # stdout
    return infile, outfile


def main():
    infile, outfile = parse_args(sys.argv[1:])
    doc = pymupdf.open(infile)
    out = open(outfile, "w", encoding="utf-8") if outfile else sys.stdout
    w = out.write
    w('<?xml version="1.0" encoding="UTF-8"?>\n')
    w('<!DOCTYPE pdf2xml SYSTEM "pdf2xml.dtd">\n')
    w('<pdf2xml producer="poppler-utils-mock" version="0.41.0">\n')
    for pno, page in enumerate(doc):
        pw, ph = page.rect.width, page.rect.height
        w(f'<page number="{pno + 1}" position="absolute" top="0" left="0" '
          f'height="{ph:.0f}" width="{pw:.0f}">\n')
        w("<flow>\n")
        words = page.get_text("words")  # x0,y0,x1,y1,word,block,line,word_no
        groups = {}
        order = []
        for x0, y0, x1, y1, word, block, line, word_no in words:
            key = (block, line)
            if key not in groups:
                groups[key] = []
                order.append(key)
            groups[key].append((x0, y0, x1, y1, word))
        for key in order:
            ws = groups[key]
            x_min = min(t[0] for t in ws)
            y_min = min(t[1] for t in ws)
            x_max = max(t[2] for t in ws)
            y_max = max(t[3] for t in ws)
            w(f'<block xMin="{x_min:.2f}" yMin="{y_min:.2f}" xMax="{x_max:.2f}" yMax="{y_max:.2f}">\n')
            w(f'<line xMin="{x_min:.2f}" yMin="{y_min:.2f}" xMax="{x_max:.2f}" yMax="{y_max:.2f}">\n')
            for x0, y0, x1, y1, word in ws:
                w(f'<word xMin="{x0:.2f}" yMin="{y0:.2f}" xMax="{x1:.2f}" yMax="{y1:.2f}">'
                  f'{sx.escape(word)}</word>\n')
            w("</line>\n</block>\n")
        w("</flow>\n</page>\n")
    w("</pdf2xml>\n")
    if outfile:
        out.close()
    doc.close()


if __name__ == "__main__":
    main()
