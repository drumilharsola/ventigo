"""Convert docs/*.md files to PDF for Acquire.com upload."""
import os, re, textwrap
from fpdf import FPDF

DOCS_DIR = os.path.join(os.path.dirname(__file__), "docs")

def sanitize(text):
    """Replace Unicode chars that latin-1 can't encode."""
    return (text
        .replace("\u2014", "--")   # em dash
        .replace("\u2013", "-")    # en dash
        .replace("\u2018", "'")    # left single quote
        .replace("\u2019", "'")    # right single quote
        .replace("\u201c", '"')    # left double quote
        .replace("\u201d", '"')    # right double quote
        .replace("\u2026", "...")  # ellipsis
        .replace("\u2022", "-")    # bullet
        .replace("\u2192", "->")   # right arrow
        .replace("\u2190", "<-")   # left arrow
        .replace("\u2713", "[x]")  # checkmark
        .replace("\u2714", "[x]")  # heavy checkmark
        .replace("\u2715", "[X]")  # X mark
        .replace("\u2716", "[X]")  # heavy X mark
        .replace("\u2717", "[ ]")  # ballot X
        .replace("\u25cf", "*")    # black circle
        .replace("\u25cb", "o")    # white circle
        .replace("\u2500", "-")    # box drawing
        .replace("\u2502", "|")    # box drawing vertical
        .replace("\u250c", "+")    # box drawing corner
        .replace("\u2510", "+")
        .replace("\u2514", "+")
        .replace("\u2518", "+")
        .replace("\u251c", "+")
        .replace("\u2524", "+")
        .replace("\u252c", "+")
        .replace("\u2534", "+")
        .replace("\u253c", "+")
        .replace("\u2550", "=")    # double horizontal
        .replace("\u2551", "||")   # double vertical
        .replace("\u25b6", ">")    # play
        .replace("\u25bc", "v")    # down arrow
        .replace("\u25b2", "^")    # up arrow
        .replace("\u2605", "*")    # star
        .replace("\u2610", "[ ]")  # ballot box
        .replace("\u2611", "[x]")  # ballot box checked
        .replace("\u2612", "[X]")  # ballot box X
        .replace("\u00a0", " ")    # non-breaking space
    )

class DocPDF(FPDF):
    def header(self):
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(140, 140, 140)
        self.cell(0, 6, "Unburden - Confidential", align="R")
        self.ln(10)

    def footer(self):
        self.set_y(-15)
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(140, 140, 140)
        self.cell(0, 10, f"Page {self.page_no()}/{{nb}}", align="C")

def md_to_pdf(md_path, pdf_path):
    pdf = DocPDF()
    pdf.alias_nb_pages()
    pdf.set_auto_page_break(auto=True, margin=20)
    pdf.add_page()

    with open(md_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    in_code_block = False
    in_table = False
    table_widths = []

    for line in lines:
        raw = sanitize(line.rstrip("\n"))

        # Code block toggle
        if raw.strip().startswith("```"):
            in_code_block = not in_code_block
            if in_code_block:
                pdf.set_font("Courier", size=8)
                pdf.set_fill_color(245, 245, 245)
            else:
                pdf.set_font("Helvetica", size=10)
            continue

        if in_code_block:
            pdf.set_font("Courier", size=7.5)
            pdf.set_fill_color(240, 240, 240)
            text = raw.replace("\t", "    ")
            # Truncate very long lines
            if len(text) > 100:
                text = text[:97] + "..."
            pdf.cell(0, 4.5, sanitize(text), fill=True, new_x="LMARGIN", new_y="NEXT")
            continue

        # Skip horizontal rules
        if raw.strip() in ("---", "***", "___"):
            pdf.ln(3)
            continue

        # Table rows
        if "|" in raw and raw.strip().startswith("|"):
            cells = [c.strip() for c in raw.strip().strip("|").split("|")]
            # Skip separator rows
            if all(set(c) <= set("- :") for c in cells):
                continue
            if not in_table:
                in_table = True
                col_count = len(cells)
                usable = pdf.w - pdf.l_margin - pdf.r_margin
                table_widths = [usable / col_count] * col_count
                # Header row
                pdf.set_font("Helvetica", "B", 8)
                pdf.set_fill_color(230, 242, 236)
                for i, cell in enumerate(cells):
                    cell = re.sub(r"\*\*(.*?)\*\*", r"\1", cell)
                    pdf.cell(table_widths[i], 6, sanitize(cell[:40]), border=1, fill=True)
                pdf.ln()
            else:
                pdf.set_font("Helvetica", size=8)
                for i, cell in enumerate(cells):
                    cell = re.sub(r"\*\*(.*?)\*\*", r"\1", cell)
                    cell = re.sub(r"`(.*?)`", r"\1", cell)
                    w = table_widths[i] if i < len(table_widths) else table_widths[-1]
                    pdf.cell(w, 5.5, sanitize(cell[:45]), border=1)
                pdf.ln()
            continue
        else:
            if in_table:
                in_table = False
                pdf.ln(3)

        # Headers
        if raw.startswith("# "):
            pdf.set_font("Helvetica", "B", 20)
            pdf.set_text_color(11, 47, 42)
            text = raw[2:].strip()
            text = re.sub(r"\*\*(.*?)\*\*", r"\1", text)
            pdf.cell(0, 12, sanitize(text), new_x="LMARGIN", new_y="NEXT")
            pdf.ln(3)
            pdf.set_text_color(0, 0, 0)
            continue
        if raw.startswith("## "):
            pdf.set_font("Helvetica", "B", 14)
            pdf.set_text_color(11, 47, 42)
            text = raw[3:].strip()
            text = re.sub(r"\*\*(.*?)\*\*", r"\1", text)
            pdf.cell(0, 10, sanitize(text), new_x="LMARGIN", new_y="NEXT")
            pdf.ln(2)
            pdf.set_text_color(0, 0, 0)
            continue
        if raw.startswith("### "):
            pdf.set_font("Helvetica", "B", 11)
            pdf.set_text_color(45, 76, 68)
            text = raw[4:].strip()
            text = re.sub(r"\*\*(.*?)\*\*", r"\1", text)
            pdf.cell(0, 8, sanitize(text), new_x="LMARGIN", new_y="NEXT")
            pdf.ln(1)
            pdf.set_text_color(0, 0, 0)
            continue

        # Bullet points
        if raw.strip().startswith("- ") or raw.strip().startswith("* "):
            pdf.set_font("Helvetica", size=10)
            bullet_text = raw.strip()[2:]
            # Handle bold in bullets
            bullet_text = re.sub(r"\*\*(.*?)\*\*", r"\1", bullet_text)
            bullet_text = re.sub(r"`(.*?)`", r"\1", bullet_text)
            pdf.cell(5)
            pdf.cell(0, 6, sanitize(f"-  {bullet_text}"), new_x="LMARGIN", new_y="NEXT")
            continue

        # Numbered items
        m = re.match(r"^(\d+)\.\s+(.*)", raw.strip())
        if m:
            pdf.set_font("Helvetica", size=10)
            text = re.sub(r"\*\*(.*?)\*\*", r"\1", m.group(2))
            text = re.sub(r"`(.*?)`", r"\1", text)
            pdf.cell(5)
            pdf.cell(0, 6, sanitize(f"{m.group(1)}.  {text}"), new_x="LMARGIN", new_y="NEXT")
            continue

        # Block quotes
        if raw.strip().startswith("> "):
            pdf.set_font("Helvetica", "I", 10)
            text = raw.strip()[2:]
            text = re.sub(r"\*\*(.*?)\*\*", r"\1", text)
            pdf.set_fill_color(230, 242, 236)
            pdf.cell(5)
            pdf.multi_cell(0, 6, sanitize(text), fill=True)
            pdf.set_font("Helvetica", size=10)
            continue

        # Empty lines
        if not raw.strip():
            pdf.ln(3)
            continue

        # Normal paragraph
        pdf.set_font("Helvetica", size=10)
        text = re.sub(r"\*\*(.*?)\*\*", r"\1", raw)
        text = re.sub(r"`(.*?)`", r"\1", text)
        pdf.multi_cell(0, 6, sanitize(text.strip()))

    pdf.output(pdf_path)
    print(f"  Created: {pdf_path}")


def main():
    files = [
        ("LISTING.md", "Unburden_Listing.pdf"),
        ("ARCHITECTURE.md", "Unburden_Architecture.pdf"),
        ("INSTALL.md", "Unburden_Install_Guide.pdf"),
        ("DATA_ROOM.md", "Unburden_Data_Room.pdf"),
    ]

    print("Converting documents to PDF...\n")
    for md_name, pdf_name in files:
        md_path = os.path.join(DOCS_DIR, md_name)
        pdf_path = os.path.join(DOCS_DIR, pdf_name)
        if os.path.exists(md_path):
            md_to_pdf(md_path, pdf_path)
        else:
            print(f"  SKIP: {md_name} not found")

    print("\nDone! Upload the PDF files from docs/ to Acquire.com.")


if __name__ == "__main__":
    main()
