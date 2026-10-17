"""Inspect executed PDF operators, including nested Form XObjects."""
from pypdf.generic import ContentStream


def pdf_operators(page, reader):
    """Yield page operators and the operators of every invoked Form occurrence."""
    def walk(stream, resources, active):
        if hasattr(resources, 'get_object'):
            resources = resources.get_object()
        objects = resources.get('/XObject', {})
        if hasattr(objects, 'get_object'):
            objects = objects.get_object()
        for operands, operator in ContentStream(stream, reader).operations:
            yield operator
            if operator != b'Do':
                continue
            reference = objects.get(operands[0])
            if reference is None:
                raise ValueError(f'Undefined PDF XObject: {operands[0]}')
            obj = reference.get_object()
            if obj.get('/Subtype') != '/Form':
                continue
            key = id(obj)
            if key in active or len(active) >= 128:
                raise ValueError('Cyclic or excessively nested PDF Form XObject')
            yield from walk(obj, obj.get('/Resources', resources), active | {key})

    contents = page.get_contents()
    if contents is not None:
        yield from walk(contents, page.get('/Resources', {}), set())
