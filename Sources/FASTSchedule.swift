/**
 * FAST Schedule class.
 *
 * @author Connor Imes
 * @date 2017-05-31
 */

/// The schedule to be applied in a window period.
/**
 We keep values as `Int` types for easier iterating, but in reality they are `UInt` types.
 The configuration IDs will be `0 <= id < FASTControllerModel.nEntries`.
 Iterations will be `0 <= nLowerIterations <= period`.
*/
public struct FASTSchedule {
    /// The lower configuration ID
    public let idLower: Int
    /// The upper configuration ID
    public let idUpper: Int
    /// The number of iterations to spend in the lower config; upper configuration gets `period - nLowerIterations`.
    public let nLowerIterations: Int
    /// Set to true if the controller observes that its signal is oscillating (and may need a new model)
    public var oscillating: Bool = false

    /// Create a `FASTSchedule` - performs assertions on parameter value ranges (must all be `>= 0`)
    public init(idLower: Int = 0, idUpper: Int = 0, nLowerIterations: Int = 0) {
        assert(idLower >= 0, "idLower must be >= 0")
        assert(idUpper >= 0, "idUpper must be >= 0")
        assert(nLowerIterations >= 0, "nLowerIterations must be >= 0")
        self.idLower = idLower
        self.idUpper = idUpper
        self.nLowerIterations = nLowerIterations
    }
}
