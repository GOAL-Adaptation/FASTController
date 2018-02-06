/**
 * FAST Schedule class.
 *
 * @author Connor Imes
 * @date 2017-05-31
 */

/// Stores user-defined parameters for the `FASTController`.
internal class FASTControllerContext {
    /// The constraint goal for measure at index `constraintMeasureIdx`.
    var constraint: Double
    /// The index of the measure we are trying to meet a constraint for (must be < `FASTControllerModel.nMeasures`).
    let constraintMeasureIdx: Int
    /// The type of optimization to perform (minimize or maximize).
    let optType: FASTControllerOptimizationType
    /// A callback that computes the value we are trying to optimize.
    let ocb: GetCostOrValueFunction
    /// The controller model.
    var model: FASTControllerModel {
        get {
            return self.model
        }
        set {
            assert(self.model.nMeasures == newValue.nMeasures, "Number of measures cannot change")
            self.setModel(newValue)
        }
    }
    /// the constraint model - sorted and normalized array for model[i][constraintMeasureIdx]
    private(set) var xupModel: [Double]!
    /// The window period (number of application jobs between controller decisions).
    var period: UInt32 {
        get {
            return self.period
        }
        set {
            self.setPeriod(newValue)
        }
    }

    /// Create a `FASTControllerContext` - performs assertions on parameter value ranges
    init(model: FASTControllerModel,
         constraint: Double,
         constraintMeasureIdx: Int,
         period: UInt32,
         optType: FASTControllerOptimizationType,
         ocb: @escaping GetCostOrValueFunction) {
        assert(constraintMeasureIdx >= 0, "constraintMeasureIdx must be >= 0")
        self.constraint = constraint
        self.constraintMeasureIdx = constraintMeasureIdx
        self.optType = optType
        self.ocb = ocb
        setModel(model)
        setPeriod(period)
    }

    private func setModel(_ model: FASTControllerModel) {
        assert(model.nMeasures > self.constraintMeasureIdx,
               "model.nMeasures (\(model.nMeasures)) must be > constraintMeasureIdx (\(self.constraintMeasureIdx))")
        // create the xupModel, normalized by the constraint measure
        var xupModel: [Double] = [Double](repeating: 0.0, count: model.nEntries)
        xupModel[0] = 1.0
        for i in 1..<xupModel.count {
            // verify that the model is properly sorted by the constraint measure
            assert(model.measures[i][constraintMeasureIdx] >= model.measures[i - 1][constraintMeasureIdx],
                   "Model not sorted by constraintMeasureIdx at entry=\(i)")
            xupModel[i] = model.measures[i][constraintMeasureIdx] / model.measures[0][constraintMeasureIdx]
        }
        self.model = model
        self.xupModel = xupModel
    }

    private func setPeriod(_ period: UInt32) {
        assert(period > 0, "period must be > 0")
        self.period = period
    }

}
