"""Regression checks for vector operators stored in PDF Form XObjects."""
import io
from pathlib import Path
import sys
import unittest

from pypdf import PdfReader, PdfWriter
from pypdf.generic import ArrayObject, DecodedStreamObject, DictionaryObject, NameObject, NumberObject

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from pdf_content import pdf_operators


class PdfContentTests(unittest.TestCase):
    def form(self, writer, data, objects=None):
        form = DecodedStreamObject()
        form.set_data(data)
        form.update({NameObject('/Type'): NameObject('/XObject'),
                     NameObject('/Subtype'): NameObject('/Form'),
                     NameObject('/BBox'): ArrayObject([NumberObject(n) for n in (0, 0, 20, 20)]),
                     NameObject('/Resources'): DictionaryObject({
                         NameObject('/XObject'): DictionaryObject(objects or {})})})
        return writer._add_object(form)

    def operators(self, writer, data, objects):
        page = writer.add_blank_page(100, 100)
        stream = DecodedStreamObject()
        stream.set_data(data)
        page[NameObject('/Contents')] = writer._add_object(stream)
        page[NameObject('/Resources')] = DictionaryObject({
            NameObject('/XObject'): DictionaryObject(objects)})
        buffer = io.BytesIO()
        writer.write(buffer)
        reader = PdfReader(io.BytesIO(buffer.getvalue()), strict=True)
        return list(pdf_operators(reader.pages[0], reader))

    def test_nested_vector_forms(self):
        writer = PdfWriter()
        inner = self.form(writer, b'0 0 m 1 1 2 2 3 3 c f')
        outer = self.form(writer, b'/Inner Do', {NameObject('/Inner'): inner})
        operators = self.operators(writer, b'/Outer Do', {NameObject('/Outer'): outer})
        self.assertEqual(operators.count(b'm'), 1)
        self.assertEqual(operators.count(b'c'), 1)

    def test_nested_font_text_is_not_hidden(self):
        writer = PdfWriter()
        inner = self.form(writer, b'BT /F1 12 Tf (text) Tj ET')
        outer = self.form(writer, b'/Inner Do', {NameObject('/Inner'): inner})
        operators = self.operators(writer, b'/Outer Do', {NameObject('/Outer'): outer})
        self.assertIn(b'BT', operators)
        self.assertIn(b'Tj', operators)

    def test_repeated_forms_count_rendered_occurrences(self):
        writer = PdfWriter()
        form = self.form(writer, b'0 0 m 1 1 2 2 3 3 c f')
        operators = self.operators(writer, b'/Glyph Do /Glyph Do', {NameObject('/Glyph'): form})
        self.assertEqual(operators.count(b'm'), 2)

    def test_unused_text_resources_are_not_rendered_text(self):
        writer = PdfWriter()
        unused = self.form(writer, b'BT (unused) Tj ET')
        operators = self.operators(writer, b'0 0 1 1 re f', {NameObject('/Unused'): unused})
        self.assertNotIn(b'BT', operators)

    def test_cyclic_forms_fail(self):
        writer = PdfWriter()
        form = self.form(writer, b'/Self Do')
        form.get_object()['/Resources']['/XObject'][NameObject('/Self')] = form
        with self.assertRaisesRegex(ValueError, 'Cyclic'):
            self.operators(writer, b'/Self Do', {NameObject('/Self'): form})


if __name__ == '__main__':
    unittest.main()
