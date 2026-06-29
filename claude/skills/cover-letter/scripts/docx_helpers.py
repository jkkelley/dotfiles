"""Rendering primitives for the cover letter engine.

This is the cover-letter skill's own copy of the shared docx helpers.
Design-system values are documented in the resume repo's CLAUDE.md.
The self-check test (test_design_system.py) asserts these constants match
that spec so drift is caught automatically.

Design system (source of truth: CLAUDE.md in the resume repo):
  Name:            26pt  Bold    #222222
  Title line:      11pt  Normal  #2E78C2
  Contact line:    8.5pt Normal  #555555
  Section headers: 10pt  Bold    #2E78C2
  Body / bullets:  9.5pt Normal  #222222
  Company lines:   9pt   Normal  #2E78C2
  Dates / school:  9.5pt Normal  #555555
  Bullet dot:      9.5pt Normal  #2E78C2
  Page: 8.5x11, margins top 0.50 bottom 0.45 left 0.50 right 0.50 (all inches)
"""

from docx.shared import Pt, Inches, RGBColor
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

# ── Color constants ───────────────────────────────────────────────────────────
DARK = RGBColor(0x22, 0x22, 0x22)
BLUE = RGBColor(0x2E, 0x78, 0xC2)
GRAY = RGBColor(0x55, 0x55, 0x55)

# ── Typography constants (pt) ─────────────────────────────────────────────────
SIZE_NAME    = 26.0
SIZE_TITLE   = 11.0
SIZE_CONTACT = 8.5
SIZE_SECTION = 10.0
SIZE_BODY    = 9.5
SIZE_COMPANY = 9.0

# ── Margin constants (inches) ─────────────────────────────────────────────────
MARGIN_TOP    = 0.50
MARGIN_BOTTOM = 0.45
MARGIN_LEFT   = 0.50
MARGIN_RIGHT  = 0.50


def run(para, text, bold=False, size=9.5, color=None):
    """Add a run to para with the given style."""
    if color is None:
        color = DARK
    r = para.add_run(text)
    r.bold = bold
    r.font.size = Pt(size)
    r.font.color.rgb = color
    return r


def page_setup(doc):
    """Apply standard 8.5x11 page dimensions and margins to a Document."""
    section = doc.sections[0]
    section.page_width    = Inches(8.5)
    section.page_height   = Inches(11)
    section.top_margin    = Inches(MARGIN_TOP)
    section.bottom_margin = Inches(MARGIN_BOTTOM)
    section.left_margin   = Inches(MARGIN_LEFT)
    section.right_margin  = Inches(MARGIN_RIGHT)

    style = doc.styles['Normal']
    style.paragraph_format.space_before = Pt(0)
    style.paragraph_format.space_after  = Pt(0)


def add_bottom_border(para, color_hex='2E78C2', sz='4', space='1'):
    """Add a bottom border to a paragraph (used under section headers)."""
    pPr = para._p.get_or_add_pPr()
    pBdr = OxmlElement('w:pBdr')
    bottom = OxmlElement('w:bottom')
    bottom.set(qn('w:val'), 'single')
    bottom.set(qn('w:sz'), sz)
    bottom.set(qn('w:space'), space)
    bottom.set(qn('w:color'), color_hex)
    pBdr.append(bottom)
    pPr.append(pBdr)


def section_header(doc, title):
    """Render a bold blue section header with a bottom border line."""
    p = doc.add_paragraph()
    pf = p.paragraph_format
    pf.space_before = Pt(7)
    pf.space_after  = Pt(3)
    run(p, title, bold=True, size=SIZE_SECTION, color=BLUE)
    add_bottom_border(p, color_hex='2E78C2')
    return p
