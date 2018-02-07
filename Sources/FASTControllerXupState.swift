/**
 * FAST Controller Xup computation.
 *
 * @author Connor Imes
 * @date 2017-05-31
 */

/// Computes a generic control signal (xup) based on current and prior xup and error values.
internal class FASTControllerXupState {
    // xups
    private var u: Double
    private var uo: Double
    private var uoo: Double
    // errors
    private var e: Double = 0.0
    private var eo: Double = 0.0
    // dominant pole
    var p1: Double {
        get {
            return self.p1
        }
        set{
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
        // compute error
        e = constraintTarget - constraintAchieved
        // Calculate xup
        u = F * ((A * uo) + (B * uoo) + (C * e) + (D * eo))
        // xup less than 1 has no effect; greater than the maximum is not achievable
        u = min(max(1.0, u), xupMax)
        // Save old values
        uoo = uo
        uo = u
        eo = e
        return u
    }

    internal func getLastXup() -> Double {
        return u
    }
}
