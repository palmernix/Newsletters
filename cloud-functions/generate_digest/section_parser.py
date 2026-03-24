"""HTML section parser for newsletter segmentation.

Splits newsletter HTML into numbered sections using structural heuristics,
injects anchor IDs at section boundaries, and extracts plain text per section.
"""

from dataclasses import dataclass
from bs4 import BeautifulSoup, Tag
import html2text
import re


@dataclass
class Section:
    index: int
    html: str
    plain_text: str


def parse_sections(html_body: str) -> tuple[list[Section], str]:
    """Parse newsletter HTML into sections based on structural heuristics.

    Returns:
        (list of Section objects, full anchored HTML string with injected anchors)
    """
    if not html_body or not html_body.strip():
        return [], html_body

    soup = BeautifulSoup(html_body, "html.parser")

    # Find the container to search within (body tag or root)
    container = soup.find("body") or soup

    # Find section boundaries
    boundaries = _find_boundaries(container)

    if not boundaries:
        # No boundaries found — treat entire body as one section
        plain = _html_to_text(html_body)
        anchor_tag = soup.new_tag("a", id="section-0")
        container.insert(0, anchor_tag)
        return [Section(index=0, html=html_body, plain_text=plain)], str(soup)

    # Inject anchors and extract sections
    sections = []
    h = html2text.HTML2Text()
    h.ignore_links = True
    h.ignore_images = True

    # Insert anchors at each boundary (in reverse order to preserve positions)
    for i, boundary in reversed(list(enumerate(boundaries))):
        anchor = soup.new_tag("a", id=f"section-{i}")
        boundary.insert_before(anchor)

    anchored_html = str(soup)

    # Now extract each section's HTML and plain text using the anchored HTML
    for i in range(len(boundaries)):
        section_html = _extract_section_html(anchored_html, i, len(boundaries))
        plain = _html_to_text(section_html)
        sections.append(Section(index=i, html=section_html, plain_text=plain))

    return sections, anchored_html


def _find_boundaries(container: Tag) -> list[Tag]:
    """Find HTML elements that mark section boundaries.

    Looks for: <hr>, <h1>-<h3>, large <table> elements, double <br> sequences.
    Only considers top-level or near-top-level elements to avoid splitting
    within nested structures.
    """
    boundaries = []
    seen_content = False

    for element in container.descendants:
        if not isinstance(element, Tag):
            continue

        tag_name = element.name.lower() if element.name else ""

        # <hr> tags are strong section boundaries
        if tag_name == "hr":
            if seen_content:
                boundaries.append(element)
            continue

        # Heading tags indicate new sections
        if tag_name in ("h1", "h2", "h3"):
            if seen_content:
                boundaries.append(element)
            seen_content = True
            continue

        # Large top-level tables (common in email HTML for content blocks)
        if tag_name == "table":
            text_content = element.get_text(strip=True)
            if len(text_content) > 200 and seen_content:
                boundaries.append(element)
                seen_content = True
            continue

        # Track whether we've seen substantial content
        if tag_name in ("p", "div", "td"):
            text = element.get_text(strip=True)
            if len(text) > 50:
                seen_content = True

    # Deduplicate: remove boundaries that are children of other boundaries
    boundaries = _remove_nested(boundaries)

    return boundaries


def _remove_nested(boundaries: list[Tag]) -> list[Tag]:
    """Remove boundary elements that are descendants of other boundaries."""
    boundary_set = set(id(b) for b in boundaries)
    result = []
    for b in boundaries:
        is_nested = False
        parent = b.parent
        while parent:
            if id(parent) in boundary_set:
                is_nested = True
                break
            parent = parent.parent
        if not is_nested:
            result.append(b)
    return result


def _extract_section_html(anchored_html: str, section_index: int, total_sections: int) -> str:
    """Extract the HTML between section-N and section-(N+1) anchors."""
    start_marker = f'id="section-{section_index}"'
    start_pos = anchored_html.find(start_marker)
    if start_pos == -1:
        return ""

    if section_index + 1 < total_sections:
        end_marker = f'id="section-{section_index + 1}"'
        end_pos = anchored_html.find(end_marker, start_pos)
        if end_pos == -1:
            return anchored_html[start_pos:]
        # Back up to include the anchor tag itself
        tag_start = anchored_html.rfind("<a ", 0, end_pos)
        if tag_start != -1:
            end_pos = tag_start
        return anchored_html[start_pos:end_pos]
    else:
        return anchored_html[start_pos:]


def _html_to_text(html: str) -> str:
    """Convert HTML to plain text, stripping links and images."""
    h = html2text.HTML2Text()
    h.ignore_links = True
    h.ignore_images = True
    h.body_width = 0
    text = h.handle(html)
    # Collapse excessive whitespace
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()
