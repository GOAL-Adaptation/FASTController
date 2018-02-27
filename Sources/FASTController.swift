/**
 * FAST Controller.
 *
 * @author Connor Imes
 * @date 2017-05-31
 */

import Foundation

/// The callback function for computing the cost or value of an array of measures
/**
 Assumes a linear interpolation of a pair of configurations `i` and `j` from the model.
 The interpolation is based on the time spent in each configuration such that the `constraint` in
 `FASTController.init()` is satisifed for measure at index `constraintMeasureIdx`.
*/
public typealias GetCostOrValueFunction = ([Double]) -> Double

/// Maintains logging config and state.
private struct FASTControllerLogState {
    // TODO: Some kind of logger or file stream

    // TODO: String formatting appears to be a pain; not consistent between Linux and Apple systems (yet)

    init() {
        // TODO: log header
    }

    func logIteration(_ id: UInt64, _ tag: UInt64, _ constraintAchieved: Double, _ workload: Double,
                      _ kf: FASTControllerKalmanFilter, _ xs: FASTControllerXupState, _ sched: FASTSchedule) {
        // TODO: log iteration
    }
}

/// A FAST controller.
public class FASTController {
    private let ctx: FASTControllerContext
    private let kf: FASTControllerKalmanFilter = FASTControllerKalmanFilter()
    private let xs: FASTControllerXupState
    private let ls: FASTControllerLogState = FASTControllerLogState()
    private var id: UInt64 = 0

    // Wrapper getters/setters

    /// Controller is deemed to be oscillating if abs(error_last - error_current) > oscillationErrorThreshold
    public var oscillationErrorThreshold: Double {
        get { return self.ctx.oscillationErrorThreshold }
        set { self.ctx.oscillationErrorThreshold = newValue }
    }

    /// The controller model
    public var model: FASTControllerModel {
        get { return self.ctx.model }
        set { self.ctx.model = newValue }
    }

    /// The controller constraint value
    public var constraint: Double {
        get { return self.ctx.constraint }
        set { self.ctx.constraint = newValue }
    }

    /// The controller optimization type
    public var optType: FASTControllerOptimizationType {
        get { return self.ctx.optType }
        set { self.ctx.optType = newValue }
    }

    /// The controller optimization callback function
    public var ocb: GetCostOrValueFunction {
        get { return self.ctx.ocb }
        set { self.ctx.ocb = newValue }
    }

    /// The controller pole value
    public var pole: Double {
        get { return self.xs.p1 }
        set { self.xs.p1 = newValue }
    }

    /// Create a `FASTController` - performs assertions on parameter values
    public init(
         model: FASTControllerModel,
         constraint: Double,
         constraintMeasureIdx: Int,
         window: UInt32,
         optType: FASTControllerOptimizationType,
         ocb: @escaping GetCostOrValueFunction,
         initialModelEntryIdx: Int) {
        assert(initialModelEntryIdx >= 0, "initialModelEntryIdx must be >= 0")
        assert(constraintMeasureIdx < model.nMeasures, "constraintMeasureIdx must be < model.nMeasures")
        self.ctx = FASTControllerContext(model: model,
                                         constraint: constraint,
                                         constraintMeasureIdx: constraintMeasureIdx,
                                         period: window,
                                         optType: optType,
                                         ocb: ocb)
        self.xs = FASTControllerXupState(model.measures[initialModelEntryIdx][constraintMeasureIdx])
    }

    /// Compute the schedule and cost for a pair of configurations.
    /**
     Called for all viable pairs of configurations.
     - parameters:
        - xupTarget: The target xup to be achieved
        - i: The upper config's index in the model
        - j: The lower config's index in the model
     - returns: The tuple (cost estimate, number of iterations in lower config)
    */
    private func computeScheduleAndCost(xupTarget: Double, i: Int, j: Int) -> (Double, Int) {
        assert(xupTarget >= 1.0)
        let xupLower = ctx.xupModel[j]
        let xupUpper = ctx.xupModel[i]
        assert(xupLower <= xupUpper)
        // Calculate the time division between the upper and lower state
        // x = percentage of the window period spent in the lower configuration
        // Conversely, (1 - x) = percentage of window period in the upper configuration
        let x: Double
        // really comparing with == since we asserted >= above, but use <= for floating point comparison
        if xupUpper <= xupLower {
            // no need for time division
            x = 0
        } else {
            // This equation ensures the time period of the combined rates is equal to the time period of the target rate
            // 1 / Target rate = X / (lower rate) + (1 - X) / (upper rate)
            x = ((xupUpper * xupLower) - (xupTarget * xupLower)) / ((xupUpper * xupTarget) - (xupTarget * xupLower))
        }
        var measuresInterpolated: [Double] = Array(repeating: 0.0, count: Int(ctx.model.nMeasures))
        for m in 0..<measuresInterpolated.count {
            measuresInterpolated[m] = x * ctx.model.measures[j][m] + (1 - x) * ctx.model.measures[i][m]
        }
        let costEstimate = ctx.ocb(measuresInterpolated)
        // Num of iterations (in lower state) = x * (controller period)
        let iterations = Int(round(Double(ctx.period) * x))
        return (costEstimate, iterations)
    }

    /// Compute the optimal schedule for the next window period.
    /**
     Called for all viable pairs of configurations.
     - parameter xupTarget: The target xup to be achieved
     - returns: The optimal `FASTSchedule` to apply in the next window period
    */
    private func computeOptimalSchedule(xupTarget: Double) -> FASTSchedule {
        var costBest: Double
        var sched: FASTSchedule = FASTSchedule()
        switch ctx.optType {
            case .minimize:
                costBest = Double.infinity
            case .maximize:
                costBest = -Double.infinity
        }
        for i in 0..<ctx.model.nEntries {
            if ctx.xupModel[i] < xupTarget {
                // upper xup must be >= xupTarget
                continue
            }
            for j in 0..<ctx.model.nEntries {
                if ctx.xupModel[j] > xupTarget {
                    // lower xup must be <= xupTarget
                    continue
                }
                let (costEstimate, iterations) = computeScheduleAndCost(xupTarget: xupTarget, i: i, j: j)
                // if this is the best configuration pair so far, remember it
                let isBest: Bool
                switch ctx.optType {
                    case .minimize:
                        isBest = costEstimate < costBest
                    case .maximize:
                        isBest = costEstimate > costBest
                }
                if isBest {
                    // use the best configuration so far
                    sched = FASTSchedule(idLower: j, idUpper: i, nLowerIterations: iterations)
                    costBest = costEstimate
                }
            }
        }
        return sched
    }

    /// Compute a schedule for the next window period.
    /**
     Called at the expiration of every window period.
     Performs some assertions on parameters.
     - parameters:
        - tag: A user-specified identifier, used only for logging purposes
        - measures: The array of measures captured during the previous window period
     - returns: The `FASTSchedule` to apply in the next window period
    */
    public func computeSchedule(tag: UInt64, measures: [Double]) -> FASTSchedule {
        assert(measures.count == ctx.model.nMeasures,
               "Length of measures must be the same as ctx.model.nMeasures (\(measures.count) != \(ctx.model.nMeasures))")
        let constraintAchieved: Double = measures[ctx.constraintMeasureIdx]
        // estimate workload
        let workload = kf.estimateBaseWorkload(xupLast: xs.u, workloadLast: constraintAchieved)
        // compute xup
        let xup = xs.calculateXup(ctx.constraint, constraintAchieved, workload, ctx.xupModel[ctx.xupModel.count - 1])
        // schedule for next window period
        var sched = computeOptimalSchedule(xupTarget: xup)
        // check for oscillation after controller should've converged; requires >= 2 prior iterations of actuation
        // (error from first iteration, which was only observation, may have been really bad, so always ignore it)
        // in short, don't act until the third iteration at the earliest (id >= 2)
        if (abs(xs.e - xs.eo) >= ctx.oscillationErrorThreshold) &&
           (self.id > max(1, UInt64(ceil(xs.getConfidenceZone())))) {
            sched.oscillating = true
        }
        // log iteration results
        ls.logIteration(self.id, tag, constraintAchieved, workload, self.kf, self.xs, sched)
        self.id += 1
        return sched
    }
    
    /// Set functions for the constraint
    @available(*, deprecated, message: "Use FASTController.constraint instead")
    public func setConstraint(_ constraint: Double) {
        self.constraint = constraint
    }

    /// Set p1 value in XupState
    @available(*, deprecated, message: "Use FASTController.pole instead")
    public func setPole(_ pole: Double) {
        self.pole = pole
    }

    /// Set model in the FASTControllerContext
    @available(*, deprecated, message: "Use FASTController.model instead")
    public func setModel(_ model: FASTControllerModel){
        self.model = model
    }

    /// Set optType in the FASTControllerContext
    @available(*, deprecated, message: "Use FASTController.optType instead")
    public func setOptType(_ optType: FASTControllerOptimizationType){
        self.optType = optType
    }

    /// Set ocb in the FASTControllerContext
    @available(*, deprecated, message: "Use FASTController.ocb instead")
    public func setOcb(_ ocb: @escaping GetCostOrValueFunction){
        self.ocb = ocb
    }

}
