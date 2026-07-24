# Integration boundaries

Expose RAD Library types at the public boundary where practical. Keep
mORMot2 serialization, ORM, HTTP or service details inside the optional
adapter. Preserve causal exceptions, document lifetime/threading rules and
avoid global mutable configuration.
