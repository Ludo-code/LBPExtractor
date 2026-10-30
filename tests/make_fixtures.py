#!/usr/bin/env python3
"""Generate synthetic LBP-style PDF fixtures for testing the shell lbpextract.

Uses PyMuPDF (fitz) to draw realistic statement pages, mimicking the layout
that `pdftotext -bbox-layout` turns into <line>/<word> XHTML.

Usage: python3 tests/make_fixtures.py OUTDIR
"""
import os
import sys

import pymupdf

PAGE_W, PAGE_H = 595, 842  # A4 points
LEFT = 40
DEBIT_X = 460   # x of debit column amounts
CREDIT_X = 530  # x of credit column amounts


def draw_page(doc, lines):
    """lines: list of (x, y, text) tuples; y is absolute from top (converted)."""
    page = doc.new_page(width=PAGE_W, height=PAGE_H)
    for x, y_top, text in lines:
        page.insert_text((x, PAGE_H - y_top), text, fontsize=9, fontname="helv")
    return page


def build_statement(path, *, account="12345678901", iban="IBAN FR76 1234 5678 9012 3456 7890 123 | BIC PSSTFRPPXXX",
                    printed="05/02/2023", year_line="Relevé édité le 05/02/2023",
                    operations=None, extra_pages=0, bon_a_savoir=True):
    """operations: list of (day, month, description, amount) amount signed float."""
    doc = pymupdf.open()
    y = 60
    L = []
    L.append((LEFT, y, "Relevé n° 2023/01 | 01/01/2023 - 31/01/2023")); y += 14
    L.append((LEFT, y, "MR JEAN DUPONT")); y += 14
    L.append((LEFT, y, "12 RUE DE LA PAIX")); y += 14
    L.append((LEFT, y, year_line)); y += 30
    L.append((LEFT, y, "Relevé de compte")); y += 14
    L.append((LEFT, y, "Vos coordonnées")); y += 14
    L.append((LEFT, y, "Téléphone conseiller 3639")); y += 30
    L.append((LEFT, y, "Situation de vos comptes")); y += 14
    L.append((LEFT, y, f"Compte courant n° {account}")); y += 14
    L.append((LEFT, y, iban)); y += 30
    L.append((LEFT, y, "  Découvert autorisé 500,00")); y += 20
    L.append((LEFT, y, "Vos opérations")); y += 14
    L.append((LEFT, y, "Date")); y += 10
    L.append((LEFT, y, "Opération")); y += 10
    L.append((LEFT, y, "Débit")); y += 10
    L.append((LEFT, y, "Crédit")); y += 10

    for day, month, desc, amount in operations or []:
        date = f"{day:02d}/{month:02d}"
        if " " in desc or len(desc) > 10:
            L.append((LEFT, y, f"{date} {desc.split('|')[0].strip()}"))
        else:
            L.append((LEFT, y, f"{date} {desc}"))
        parts = desc.split("|")
        for p in parts[1:]:
            y += 10
            L.append((LEFT, y, p.strip()))
        if amount < 0:
            L.append((DEBIT_X, y, f"{abs(amount):,.2f}".replace(",", " ").replace(".", ",")))
        else:
            L.append((CREDIT_X, y, f"{amount:,.2f}".replace(",", " ").replace(".", ",")))
        y += 14

    L.append((LEFT, y, "Ancien solde au 01/01/2023")); y += 10
    L.append((CREDIT_X, y, "1 000,00")); y += 14
    L.append((LEFT, y, "Nouveau solde au 31/01/2023")); y += 10
    L.append((CREDIT_X, y, "3 326,55")); y += 14
    L.append((LEFT, y, "Total des opérations")); y += 10
    L.append((CREDIT_X, y, "2 326,55")); y += 30
    if bon_a_savoir:
        L.append((LEFT, y, "BON À SAVOIR")); y += 14
        L.append((LEFT, y, "Pour votre information, conservez ce relevé.")); y += 14
    draw_page(doc, L)

    for _ in range(extra_pages):
        page = doc.new_page(width=PAGE_W, height=PAGE_H)
        page.insert_text((LEFT, 60), "Vos opérations n° 2023/01 (suite)", fontsize=9)
        page.insert_text((LEFT, 80), "Page 2/2", fontsize=9)

    doc.save(path)
    doc.close()


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else "tests/fixtures"
    os.makedirs(outdir, exist_ok=True)

    build_statement(
        os.path.join(outdir, "releve_jan.pdf"),
        operations=[
            (3, 1, "PRELEVEMENT EDF", -123.45),
            (10, 1, "VIREMENT SALAIRE", 2500.00),
            (12, 1, "CARTE | RETRAIT DAB", -50.00),
        ],
    )
    build_statement(
        os.path.join(outdir, "releve_dec.pdf"),
        printed="05/01/2024",
        year_line="Relevé édité le 05/01/2024",
        operations=[
            (15, 12, "PRELEVEMENT EDF", -100.00),
            (20, 1, "VIREMENT", 1500.00),
        ],
    )
    # duplicate of january (same content -> duplicate detection)
    build_statement(
        os.path.join(outdir, "releve_jan_copy.pdf"),
        operations=[
            (3, 1, "PRELEVEMENT EDF", -123.45),
            (10, 1, "VIREMENT SALAIRE", 2500.00),
            (12, 1, "CARTE | RETRAIT DAB", -50.00),
        ],
    )
    # second account in the same file set
    build_statement(
        os.path.join(outdir, "releve_livret.pdf"),
        account="98765432109",
        operations=[(5, 1, "INTERETS", 12.34)],
    )
    # old statement with a "Soit en francs" extra column (x < 400 => debit)
    doc = pymupdf.open()
    y = 60
    L = []
    L.append((LEFT, y, "Relevé n° 2001/06 | 01/06/2001 - 30/06/2001")); y += 14
    L.append((LEFT, y, "MME MARIE MARTIN")); y += 14
    L.append((LEFT, y, "Relevé édité le 05/07/2001")); y += 30
    L.append((LEFT, y, "Relevé de compte")); y += 14
    L.append((LEFT, y, "Vos coordonnées")); y += 14
    L.append((LEFT, y, "Téléphone conseiller 3639")); y += 30
    L.append((LEFT, y, "Situation de vos comptes")); y += 14
    L.append((LEFT, y, "Compte courant n° 55555555555")); y += 14
    L.append((LEFT, y, "IBAN FR76 5555 | BIC PSSTFRPPXXX")); y += 30
    L.append((LEFT, y, "Vos opérations")); y += 14
    L.append((LEFT, y, "Date")); y += 10
    L.append((LEFT, y, "Opération")); y += 10
    L.append((LEFT, y, "Débit")); y += 10
    L.append((LEFT, y, "Crédit")); y += 10
    L.append((LEFT, y, "Soit en francs")); y += 10
    L.append((LEFT, y, "08/06 PRELEVEMENT")); L.append((350, y, "200,00")); L.append((450, y, "1 310,40")); y += 14
    L.append((LEFT, y, "20/06 VIREMENT")); L.append((450, y, "1 000,00")); L.append((350, y, "6 562,00")); y += 14
    L.append((LEFT, y, "Ancien solde au 01/06/2001")); y += 10
    L.append((450, y, "500,00")); y += 14
    L.append((LEFT, y, "Nouveau solde au 30/06/2001")); y += 10
    L.append((450, y, "1 300,00")); y += 14
    L.append((LEFT, y, "Total des opérations")); y += 10
    L.append((450, y, "800,00")); y += 14
    draw_page(doc, L)
    doc.save(os.path.join(outdir, "releve_2001_francs.pdf"))
    doc.close()
    print(f"fixtures written to {outdir}")


if __name__ == "__main__":
    main()
