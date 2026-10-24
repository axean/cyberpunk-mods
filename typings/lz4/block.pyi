# Minimal stub for the functions used here; python-lz4 ships no type information.
def compress(
    source: bytes,
    mode: str = ...,
    acceleration: int = ...,
    compression: int = ...,
    store_size: bool = ...,
) -> bytes: ...
def decompress(source: bytes, uncompressed_size: int = ...) -> bytes: ...
