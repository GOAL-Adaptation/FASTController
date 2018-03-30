/**
 * FAST Controller Model class.
 *
 * @author Connor Imes
 * @date 2017-05-31
 */

/// A model for the FAST controller to use.
/**
 The `measures` matrix must be sorted by column at index `constraintMeasureIdx` s.t. for all `i >= 0`:
    `measures[i][constraintMeasureIdx] <= measures[i + 1][constraintMeasureIdx]`.
*/
public class FASTControllerModel {
    /// the matrix, essentially the "table" that the controller uses as a model.
    public let measures: [[Double]]
    // values cached for convenience and readability
    internal let nEntries: Int
    internal let nMeasures: Int

    /// Create a `FASTControllerModel` - performs assertions on sizing and sorting
    public init(measures: [[Double]]) {
        let nEntries = measures.count
        assert(nEntries > 0, "measures array must not be empty (nEntries = 0)")
        let nMeasures = measures[0].count
        assert(nMeasures > 0, "measures array must not be empty (nMeasures = 0)")
        // verify that the matrix is properly sized
        for i in 1..<nEntries {
            assert(measures[i].count == nMeasures,
                   "Model must have consistent size: entry=\(i) does not have nMeasures=\(nMeasures)")
        }
        self.measures = measures
        self.nEntries = nEntries
        self.nMeasures = nMeasures
    }
}
