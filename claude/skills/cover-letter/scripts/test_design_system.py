"""Self-check: assert docx_helpers.py constants match the documented design system.

Design-system spec lives in CLAUDE.md in the resume repo.
Run: python3 test_design_system.py
"""

import sys
import os

sys.path.insert(0, os.path.dirname(__file__))
import docx_helpers as h
from docx.shared import RGBColor


def assert_eq(name, got, expected):
    assert got == expected, f'{name}: expected {expected!r}, got {got!r}'


def test_colors():
    # RGBColor is a subclass of int; compare via hex string representation
    assert_eq('DARK', str(h.DARK).upper(), '222222')
    assert_eq('BLUE', str(h.BLUE).upper(), '2E78C2')
    assert_eq('GRAY', str(h.GRAY).upper(), '555555')


def test_sizes():
    assert_eq('SIZE_NAME',    h.SIZE_NAME,    26.0)
    assert_eq('SIZE_TITLE',   h.SIZE_TITLE,   11.0)
    assert_eq('SIZE_CONTACT', h.SIZE_CONTACT, 8.5)
    assert_eq('SIZE_SECTION', h.SIZE_SECTION, 10.0)
    assert_eq('SIZE_BODY',    h.SIZE_BODY,    9.5)
    assert_eq('SIZE_COMPANY', h.SIZE_COMPANY, 9.0)


def test_margins():
    assert_eq('MARGIN_TOP',    h.MARGIN_TOP,    0.50)
    assert_eq('MARGIN_BOTTOM', h.MARGIN_BOTTOM, 0.45)
    assert_eq('MARGIN_LEFT',   h.MARGIN_LEFT,   0.50)
    assert_eq('MARGIN_RIGHT',  h.MARGIN_RIGHT,  0.50)


if __name__ == '__main__':
    test_colors()
    test_sizes()
    test_margins()
    print('design-system self-check: all constants match spec')
