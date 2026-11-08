"""Make a small sample PDF for the RAG test: a fictional company handbook with facts we can check answers against."""
from fpdf import FPDF

PAGES = [
    ("Northwind Labs handbook (sample document for a RAG test; the company is fictional)",
     ["Refunds. Customers can ask for a full refund within 14 days of purchase. After 14 days we offer store credit only. "
      "Refunds are paid back to the original card within 5 business days.",
      "Support hours. The support desk is open Monday to Friday, 8:00 to 18:00 Kuala Lumpur time. "
      "Urgent outages on the Enterprise plan are answered within 1 hour, at any time."]),
    ("Plans and prices",
     ["The Starter plan costs 19 US dollars a month and includes 3 users. The Team plan costs 79 US dollars a month and includes 15 users. "
      "Each extra user costs 6 US dollars a month.",
      "Annual billing gives two months free on every plan."]),
    ("Security",
     ["Customer data is stored in the Singapore region. Backups are taken every 6 hours and kept for 30 days.",
      "Staff laptops use full-disk encryption, and access to production requires a hardware security key."]),
]

pdf = FPDF()
pdf.set_auto_page_break(True, 20)
for title, paras in PAGES:
    pdf.add_page()
    pdf.set_font("Helvetica", "B", 15)
    pdf.multi_cell(0, 8, title)
    pdf.ln(4)
    pdf.set_font("Helvetica", "", 11)
    for p in paras:
        pdf.multi_cell(0, 6, p)
        pdf.ln(3)
pdf.output("docs/northwind-handbook.pdf")
print("wrote docs/northwind-handbook.pdf,", len(PAGES), "pages")
