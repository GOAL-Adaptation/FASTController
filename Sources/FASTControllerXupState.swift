/**
 * FAST Controller Xup computation.
 *
 * @author Connor Imes
 * @date 2017-05-31
 */

/// Computes a generic control signal (xup) based on current and prior xup and error values.
internal class FASTControllerXupState {
    // xups
    private(set) var u: Double
    private var uo: Double
    private var uoo: Double
    // errors
    private(set) var e: Double = 0.0
    private(set) var eo: Double = 0.0
    // dominant pole
    private var p1: Double
    var pole: Double {
        get {
            return self.p1
        }
        set {
            assert((newValue >= 0) && (newValue < 1), "Pole values should be in [0,1) range")
            self.p1 = newValue;
        }
    }
    // constants
    // second pole
    private let p2: Double = 0.0
    // zero
    private let z1: Double = 0.0
    // gain
    private let mu: Double = 1.0

    init(_ xupStart: Double) {
        self.u = xupStart
        self.uo = xupStart
        self.uoo = xupStart
        self.p1 = 0.0
    }

    /// Calculate the xup to achieve in the next window period (control iteration).
    /**
     Uses and updates this instance's state (history of xup and error).
     - parameters:
        - constraintTarget: The target value to be achieved
        - constraintAchieved: The value tha was achieved in the previous iteration
        - w: The base workload estimated by the Kalman filter
        - xupMax: The maximum xup that is allowed (minimum is assumed to be 1.0)
     - returns: The new xup to achieve
    */
    internal func calculateXup(_ constraintTarget: Double, _ constraintAchieved: Double,
                               _ w: Double, _ xupMax: Double) -> Double {
        let A = -(-(p1 * z1) - (p2 * z1) + (mu * p1 * p2) - (mu * p2) + p2 - (mu * p1) + p1 + mu)
        let B = -(-(mu * p1 * p2 * z1) + (p1 * p2 * z1) + (mu * p2 * z1) + (mu * p1 * z1) - (mu * z1) - (p1 * p2))
        let C = (((mu - (mu * p1)) * p2) + (mu * p1) - mu) * w
        let D = ((((mu * p1) - mu) * p2) - (mu * p1) + mu) * w * z1
        let F = 1.0 / (z1 - 1.0)
        // Save old values
        uoo = uo
        uo = u
        eo = e
        // compute error
        e = constraintTarget - constraintAchieved
        // Calculate xup
        u = F * ((A * uo) + (B * uoo) + (C * e) + (D * eo))
        // xup less than 1 has no effect; greater than the maximum is not achievable
        u = min(max(1.0, u), xupMax)
        return u
    }

    /// Minimum number of control steps before the controller should settle within epsilon percent of the constraint.
    /// A function of the pole value and epsilon; usually epsilon = 0.05.
    /// See: A. Filieri et al. Software Engineering Meets Control Theory. In: SEAMS. 2015.
    /**
     Compute the confidence zone.
     - parameters:
        - epsilon: the percent of the constraint the controller should be converged within, in range (0,1)
     - returns: log(epsilon)/log(pole), or 0 if pole = 0 (value always >= 0)
    */
    internal func getConfidenceZone(_ epsilon: Double = 0.05) -> Double {
        assert(epsilon > 0.0 && epsilon < 1.0, "Epsilon must be in range (0,1)");
        // expect instantaneous settling if pole is 0
        return self.p1 > 0.0 ? (_log2(epsilon) / _log2(self.p1)) : 0.0;
    }

}
