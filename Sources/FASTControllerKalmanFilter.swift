/**
 * FAST Schedule class.
 *
 * @author Connor Imes
 * @date 2017-05-31
 */

/// The Kalman filter for estimating base workload.
internal class FASTControllerKalmanFilter {
    private var x_hat_minus: Double = 0.0
    private var x_hat: Double = 0.2
    private var p_minus: Double = 0.0
    private var h: Double = 0.0
    private var k: Double = 0.0
    private var p: Double = 1.0
    // constants
    private let q: Double = 0.00001
    private let r: Double = 0.01

    /// Estimate the base workload from the last iteration's xup and the resulting behavior.
    /**
     Uses and updates the state of the Kalman filter.
     - parameters:
        - xupLast: The xup that was targeted for the last iteration
        - workloadLast: The workload achieved in the last iteration
     - returns: The base workload estimate
    */
    internal func estimateBaseWorkload(xupLast: Double, workloadLast: Double) -> Double {
        x_hat_minus = x_hat
        p_minus = p + q
        h = xupLast
        k = (p_minus * h) / ((h * p_minus * h) + r)
        x_hat = x_hat_minus + (k * (workloadLast - (h * x_hat_minus)))
        p = (1.0 - (k * h)) * p_minus
        return 1.0 / x_hat
    }
}
