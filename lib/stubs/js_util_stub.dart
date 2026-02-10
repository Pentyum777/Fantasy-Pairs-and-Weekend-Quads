// Stub for non-web platforms
T getProperty<T>(Object o, Object name) =>
    throw UnsupportedError('Not available on this platform');

void setProperty(Object o, Object name, Object value) =>
    throw UnsupportedError('Not available on this platform');

dynamic allowInterop(Function f) =>
    throw UnsupportedError('Not available on this platform');