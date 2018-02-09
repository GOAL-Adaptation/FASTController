import XCTest
@testable import FASTController

class FASTControllerTests: XCTestCase {
    let MEASURE_XUP_IDX = 0
    let MEASURE_COSTUP_IDX = 1
    let N_MEASURES = 2
    let TEST_MEASURES: [[Double]] = [ [1, 1], [4, 6], [8, 10] ]
    // the constraint (performance) value we wish to meet
    let CONSTRAINT: Double = 100
    // the window period (iterations)
    let WINDOW_PERIOD: UInt32 = 10

    func testControllerModel() {
        let _ = FASTControllerModel(measures: TEST_MEASURES)
    }

    func testFASTSchedule() {
        var _ = FASTSchedule()
        var _ = FASTSchedule(idLower: 1, idUpper: 1, nLowerIterations: 1)
    }

    fileprivate func callback(measuresInterpolated: [Double]) -> Double {
        return measuresInterpolated[MEASURE_COSTUP_IDX] / measuresInterpolated[MEASURE_XUP_IDX]
    }

    func testFASTController() {
        let model = FASTControllerModel(measures: TEST_MEASURES)
        let fc = FASTController(model: model,
                                constraint: CONSTRAINT,
                                constraintMeasureIdx: MEASURE_XUP_IDX,
                                window: WINDOW_PERIOD,
                                optType: .minimize,
                                ocb: callback,
                                initialModelEntryIdx: 0)
        // test setters (previous impls were causing infinite recursion)
        fc.setConstraint(CONSTRAINT)
        fc.setPole(0)
        fc.setModel(model)
        var iterMeasures: [Double] = [ 0.0, 0.0 ]
        for i in 0...WINDOW_PERIOD {
            // do app work here...
            // at each window period, call the controller
            if i > 0 && i % WINDOW_PERIOD == 0 {
                // in practice this would look simpler - just capture the values of each measure and call fc.computeSchedule(...)
                // the following if statements are us faking the measure values...
                if (i == WINDOW_PERIOD) {
                    iterMeasures[MEASURE_XUP_IDX] = CONSTRAINT / 4
                    iterMeasures[MEASURE_COSTUP_IDX] = 10
                } else if (i == 2 * WINDOW_PERIOD) {
                    iterMeasures[MEASURE_XUP_IDX] = CONSTRAINT / 2
                    iterMeasures[MEASURE_COSTUP_IDX] = 10
                }
                let sched = fc.computeSchedule(tag: UInt64(i), measures: iterMeasures)
                // testing that the controller worked ...
                // TODO: These expected results aren't actually verified...
                if (i == WINDOW_PERIOD) {
                    XCTAssert(sched.idLower == 0)
                    XCTAssert(sched.idUpper == 2)
                    XCTAssert(sched.nLowerIterations == 1)
                } else if (i == 2 * WINDOW_PERIOD) {
                    iterMeasures[MEASURE_XUP_IDX] = CONSTRAINT / 2
                    iterMeasures[MEASURE_COSTUP_IDX] = 10
                    XCTAssert(sched.idLower == 0)
                    XCTAssert(sched.idUpper == 2)
                    XCTAssert(sched.nLowerIterations == 0)
                }
            }
        }
        // the runtime checks the schedule here to see if it needs to actuate application or system changes
    }

    static var allTests = [
        ("testControllerModel", testControllerModel),
        ("testFASTSchedule", testFASTSchedule),
        ("testFASTController", testFASTController),
    ]
}
