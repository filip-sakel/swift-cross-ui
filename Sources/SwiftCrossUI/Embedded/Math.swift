import _EmbdeddedShims

#if hasFeature(Embedded)
// Bring in trig functions from _EmbeddedShims
internal func sin(_ x: Double) -> Double {
    return libm_sin(x)
}
internal func cos(_ x: Double) -> Double {
    return libm_cos(x)
}
#endif