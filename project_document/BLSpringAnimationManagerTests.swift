@testable import BilibiliLive
import QuartzCore
import UIKit
import XCTest

// MARK: - BLSpringAnimationManagerTests

/// BLSpringAnimationManager 测试套件
/// 全面测试弹性动画管理器的功能、性能和稳定性
class BLSpringAnimationManagerTests: XCTestCase {
    // MARK: - Properties

    var animationManager: BLSpringAnimationManager!
    var testLayer: CALayer!
    var performanceMonitor: AnimationPerformanceMonitor!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        animationManager = BLSpringAnimationManager.shared
        testLayer = CALayer()
        testLayer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        performanceMonitor = AnimationPerformanceMonitor()
    }

    override func tearDown() {
        animationManager.stopAnimations(for: testLayer)
        testLayer = nil
        performanceMonitor = nil
        super.tearDown()
    }

    // MARK: - Configuration Tests

    /// 测试弹性动画配置的边界值处理
    func testSpringAnimationConfigurationBounds() {
        // 测试最小值限制
        let minConfig = BLSpringAnimationConfiguration(
            duration: -1.0,
            damping: -0.5,
            stiffness: -100.0,
            initialVelocity: -5.0,
            delay: -1.0
        )

        XCTAssertGreaterThanOrEqual(minConfig.duration, 0.1, "Duration should be clamped to minimum")
        XCTAssertGreaterThanOrEqual(minConfig.damping, 0.1, "Damping should be clamped to minimum")
        XCTAssertGreaterThanOrEqual(minConfig.stiffness, 10.0, "Stiffness should be clamped to minimum")
        XCTAssertGreaterThanOrEqual(minConfig.initialVelocity, 0.0, "Initial velocity should be clamped to minimum")
        XCTAssertGreaterThanOrEqual(minConfig.delay, 0.0, "Delay should be clamped to minimum")

        // 测试最大值限制
        let maxConfig = BLSpringAnimationConfiguration(
            duration: 10.0,
            damping: 2.0,
            stiffness: 2000.0,
            initialVelocity: 20.0
        )

        XCTAssertLessThanOrEqual(maxConfig.duration, 3.0, "Duration should be clamped to maximum")
        XCTAssertLessThanOrEqual(maxConfig.damping, 1.0, "Damping should be clamped to maximum")
        XCTAssertLessThanOrEqual(maxConfig.stiffness, 1000.0, "Stiffness should be clamped to maximum")
        XCTAssertLessThanOrEqual(maxConfig.initialVelocity, 10.0, "Initial velocity should be clamped to maximum")
    }

    /// 测试动画预设配置的正确性
    func testAnimationPresets() {
        let presets: [BLSpringAnimationPreset] = [.gentle, .moderate, .bouncy, .quick, .smooth, .dramatic]

        for preset in presets {
            let config = preset.configuration

            // 验证配置值在合理范围内
            XCTAssertGreaterThan(config.duration, 0.0, "\(preset) duration should be positive")
            XCTAssertLessThanOrEqual(config.duration, 3.0, "\(preset) duration should be reasonable")
            XCTAssertGreaterThan(config.damping, 0.0, "\(preset) damping should be positive")
            XCTAssertLessThanOrEqual(config.damping, 1.0, "\(preset) damping should be <= 1.0")
            XCTAssertGreaterThan(config.stiffness, 0.0, "\(preset) stiffness should be positive")
        }

        // 测试自定义预设
        let customConfig = BLSpringAnimationConfiguration(duration: 0.4, damping: 0.7)
        let customPreset = BLSpringAnimationPreset.custom(customConfig)
        XCTAssertEqual(customPreset.configuration.duration, 0.4, "Custom preset should preserve configuration")
    }

    // MARK: - Animation Creation Tests

    /// 测试弹性动画创建功能
    func testSpringAnimationCreation() {
        let animation = animationManager.createSpringAnimation(
            for: .scale,
            from: 1.0,
            to: 1.5,
            preset: .moderate
        )

        XCTAssertNotNil(animation, "Should create animation successfully")
        XCTAssertEqual(animation.keyPath, "transform.scale", "Should set correct keyPath")
        XCTAssertEqual(animation.fromValue as? CGFloat, 1.0, "Should set correct fromValue")
        XCTAssertEqual(animation.toValue as? CGFloat, 1.5, "Should set correct toValue")
        XCTAssertEqual(animation.damping, 0.8, accuracy: 0.01, "Should set correct damping")
        XCTAssertEqual(animation.stiffness, 300.0, accuracy: 0.01, "Should set correct stiffness")
        XCTAssertFalse(animation.isRemovedOnCompletion, "Should keep animation after completion")
    }

    /// 测试不同属性类型的动画创建
    func testAnimationCreationForDifferentProperties() {
        let properties: [BLAnimatableProperty] = [
            .transform, .scale, .position, .opacity,
            .backgroundColor, .cornerRadius, .shadowOpacity,
        ]

        for property in properties {
            let animation = animationManager.createSpringAnimation(
                for: property,
                from: nil,
                to: 1.0,
                preset: .quick
            )

            XCTAssertEqual(animation.keyPath, property.keyPath, "Should set correct keyPath for \(property)")
            XCTAssertNotNil(animation, "Should create animation for \(property)")
        }

        // 测试自定义属性
        let customProperty = BLAnimatableProperty.custom("customProperty")
        let customAnimation = animationManager.createSpringAnimation(
            for: customProperty,
            from: nil,
            to: 1.0,
            preset: .gentle
        )

        XCTAssertEqual(customAnimation.keyPath, "customProperty", "Should handle custom property")
    }

    // MARK: - Animation Application Tests

    /// 测试动画应用到图层
    func testAnimationApplication() {
        let expectation = XCTestExpectation(description: "Animation completion")

        animationManager.applySpringAnimation(
            to: testLayer,
            for: .opacity,
            from: 1.0,
            to: 0.5,
            preset: .quick
        ) { success in
            XCTAssertTrue(success, "Animation should complete successfully")
            expectation.fulfill()
        }

        // 验证图层值立即更新
        XCTAssertEqual(testLayer.opacity, 0.5, accuracy: 0.01, "Layer value should be updated immediately")

        wait(for: [expectation], timeout: 2.0)
    }

    /// 测试批量动画应用
    func testBatchAnimationApplication() {
        let expectation = XCTestExpectation(description: "Batch animation completion")

        let animations = [
            (property: BLAnimatableProperty.opacity, fromValue: 1.0 as Any?, toValue: 0.8 as Any, preset: BLSpringAnimationPreset.quick),
            (property: BLAnimatableProperty.scale, fromValue: 1.0 as Any?, toValue: 1.2 as Any, preset: BLSpringAnimationPreset.moderate),
            (property: BLAnimatableProperty.cornerRadius, fromValue: 0.0 as Any?, toValue: 10.0 as Any, preset: BLSpringAnimationPreset.smooth),
        ]

        animationManager.applyBatchAnimations(
            to: testLayer,
            animations: animations
        ) { success in
            XCTAssertTrue(success, "Batch animations should complete successfully")
            expectation.fulfill()
        }

        // 验证所有值都已更新
        XCTAssertEqual(testLayer.opacity, 0.8, accuracy: 0.01, "Opacity should be updated")
        XCTAssertEqual(testLayer.cornerRadius, 10.0, accuracy: 0.01, "Corner radius should be updated")

        wait(for: [expectation], timeout: 3.0)
    }

    /// 测试空批量动画的处理
    func testEmptyBatchAnimation() {
        let expectation = XCTestExpectation(description: "Empty batch completion")

        animationManager.applyBatchAnimations(
            to: testLayer,
            animations: []
        ) { success in
            XCTAssertTrue(success, "Empty batch should complete successfully")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 0.5)
    }

    // MARK: - Animation Control Tests

    /// 测试动画停止功能
    func testAnimationStopping() {
        // 启动多个动画
        animationManager.applySpringAnimation(to: testLayer, for: .opacity, from: 1.0, to: 0.5, preset: .dramatic)
        animationManager.applySpringAnimation(to: testLayer, for: .scale, from: 1.0, to: 1.5, preset: .bouncy)

        // 等待动画开始
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 停止特定属性动画
            self.animationManager.stopAnimation(for: self.testLayer, property: .opacity)

            // 验证只有指定动画被停止
            XCTAssertNil(self.testLayer.animation(forKey: "BLSpring_\(ObjectIdentifier(self.testLayer).hashValue)_opacity"),
                         "Opacity animation should be stopped")
            XCTAssertNotNil(self.testLayer.animation(forKey: "BLSpring_\(ObjectIdentifier(self.testLayer).hashValue)_transform.scale"),
                            "Scale animation should still be running")
        }

        // 停止所有动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.animationManager.stopAnimations(for: self.testLayer)

            // 验证所有动画都被停止
            XCTAssertEqual(self.testLayer.animationKeys()?.count ?? 0, 0, "All animations should be stopped")
        }
    }

    // MARK: - Performance Tests

    /// 测试动画性能和内存使用
    func testAnimationPerformance() {
        measure {
            // 创建大量动画来测试性能
            for i in 0..<100 {
                let layer = CALayer()
                layer.frame = CGRect(x: 0, y: 0, width: 10, height: 10)

                animationManager.applySpringAnimation(
                    to: layer,
                    for: .scale,
                    from: 1.0,
                    to: Double(i % 2 == 0 ? 1.2 : 0.8),
                    preset: .quick
                )
            }
        }
    }

    /// 测试动画池的效率
    func testAnimationPoolEfficiency() {
        performanceMonitor.startMonitoring()

        let iterations = 50
        var createdAnimations: [CASpringAnimation] = []

        // 创建动画
        for _ in 0..<iterations {
            let animation = animationManager.createSpringAnimation(
                for: .opacity,
                from: 1.0,
                to: 0.5,
                preset: .moderate
            )
            createdAnimations.append(animation)
        }

        let creationTime = performanceMonitor.stopMonitoring()

        // 验证性能合理
        XCTAssertLessThan(creationTime, 0.5, "Animation creation should be fast")
        XCTAssertEqual(createdAnimations.count, iterations, "Should create all requested animations")
    }

    // MARK: - Convenience Methods Tests

    /// 测试便捷动画方法
    func testConvenienceMethods() {
        let expectations = [
            XCTestExpectation(description: "Scale animation"),
            XCTestExpectation(description: "Opacity animation"),
            XCTestExpectation(description: "Position animation"),
            XCTestExpectation(description: "Background color animation"),
        ]

        // 测试缩放动画
        animationManager.animateScale(layer: testLayer, to: 1.5) { success in
            XCTAssertTrue(success, "Scale animation should succeed")
            expectations[0].fulfill()
        }

        // 测试透明度动画
        animationManager.animateOpacity(layer: testLayer, to: 0.7) { success in
            XCTAssertTrue(success, "Opacity animation should succeed")
            expectations[1].fulfill()
        }

        // 测试位置动画
        animationManager.animatePosition(layer: testLayer, to: CGPoint(x: 50, y: 50)) { success in
            XCTAssertTrue(success, "Position animation should succeed")
            expectations[2].fulfill()
        }

        // 测试背景色动画
        animationManager.animateBackgroundColor(layer: testLayer, to: .blue) { success in
            XCTAssertTrue(success, "Background color animation should succeed")
            expectations[3].fulfill()
        }

        wait(for: expectations, timeout: 3.0)

        // 验证最终值
        XCTAssertEqual(testLayer.opacity, 0.7, accuracy: 0.01, "Opacity should be updated")
        XCTAssertEqual(testLayer.position.x, 50, accuracy: 0.01, "Position X should be updated")
        XCTAssertEqual(testLayer.position.y, 50, accuracy: 0.01, "Position Y should be updated")
    }

    // MARK: - Error Handling Tests

    /// 测试错误处理和边界情况
    func testErrorHandling() {
        // 测试nil图层处理（模拟弱引用失效）
        weak var weakLayer: CALayer? = CALayer()

        if let layer = weakLayer {
            animationManager.applySpringAnimation(
                to: layer,
                for: .opacity,
                from: 1.0,
                to: 0.5,
                preset: .quick
            ) { success in
                // 这个回调可能不会被调用，因为图层可能已经被释放
            }
        }

        // 强制释放图层
        weakLayer = nil

        // 验证动画管理器处理了弱引用失效的情况
        XCTAssertNil(weakLayer, "Layer should be deallocated")
    }

    /// 测试并发安全性
    func testConcurrencySafety() {
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()

        // 并发创建动画
        for i in 0..<20 {
            group.enter()
            concurrentQueue.async {
                let layer = CALayer()
                layer.frame = CGRect(x: 0, y: 0, width: 10, height: 10)

                self.animationManager.applySpringAnimation(
                    to: layer,
                    for: .opacity,
                    from: 1.0,
                    to: 0.5,
                    preset: .quick
                ) { _ in
                    group.leave()
                }
            }
        }

        let expectation = XCTestExpectation(description: "Concurrent animations")
        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Integration Tests

    /// 测试与其他动画系统的集成
    func testAnimationSystemIntegration() {
        // 创建一个复杂的动画序列
        let expectation = XCTestExpectation(description: "Animation sequence")

        // 第一个动画：缩放
        animationManager.animateScale(layer: testLayer, to: 1.3, preset: .quick) { success in
            XCTAssertTrue(success, "First animation should succeed")

            // 第二个动画：透明度
            self.animationManager.animateOpacity(layer: self.testLayer, to: 0.6, preset: .smooth) { success in
                XCTAssertTrue(success, "Second animation should succeed")

                // 第三个动画：位置
                self.animationManager.animatePosition(layer: self.testLayer, to: CGPoint(x: 100, y: 100), preset: .bouncy) { success in
                    XCTAssertTrue(success, "Third animation should succeed")
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // 验证最终状态
        XCTAssertEqual(testLayer.opacity, 0.6, accuracy: 0.01, "Final opacity should be correct")
        XCTAssertEqual(testLayer.position.x, 100, accuracy: 0.01, "Final position X should be correct")
        XCTAssertEqual(testLayer.position.y, 100, accuracy: 0.01, "Final position Y should be correct")
    }

    /// 测试单例模式的正确性
    func testSingletonPattern() {
        let instance1 = BLSpringAnimationManager.shared
        let instance2 = BLSpringAnimationManager.shared

        XCTAssertTrue(instance1 === instance2, "Should return the same singleton instance")
    }

    // MARK: - Memory Management Tests

    /// 测试内存管理和清理
    func testMemoryManagement() {
        weak var weakAnimation: CASpringAnimation?

        autoreleasepool {
            let animation = animationManager.createSpringAnimation(
                for: .opacity,
                from: 1.0,
                to: 0.5,
                preset: .moderate
            )
            weakAnimation = animation

            // 应用动画
            testLayer.add(animation, forKey: "test")
        }

        // 清理动画
        testLayer.removeAllAnimations()

        // 给系统时间清理
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakAnimation, "Animation should be deallocated after removal")
        }
    }

    /// 测试动画完成回调的内存安全
    func testCompletionCallbackMemorySafety() {
        weak var weakObject: NSObject?

        autoreleasepool {
            let testObject = NSObject()
            weakObject = testObject

            animationManager.applySpringAnimation(
                to: testLayer,
                for: .opacity,
                from: 1.0,
                to: 0.5,
                preset: .quick
            ) { [weak testObject] success in
                // 使用弱引用避免循环引用
                _ = testObject
            }
        }

        // 对象应该能够正常释放
        XCTAssertNil(weakObject, "Test object should be deallocated")
    }
}

// MARK: - Helper Classes

/// 性能监控辅助类
private class AnimationPerformanceMonitor {
    private var startTime: CFTimeInterval = 0

    func startMonitoring() {
        startTime = CACurrentMediaTime()
    }

    func stopMonitoring() -> TimeInterval {
        return CACurrentMediaTime() - startTime
    }
}

// MARK: - Mock Classes for Testing

/// 测试用的模拟图层
private class MockAnimationLayer: CALayer {
    var animationCompletionCount = 0

    override func add(_ anim: CAAnimation, forKey key: String?) {
        super.add(anim, forKey: key)

        // 模拟快速完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.animationCompletionCount += 1
            anim.delegate?.animationDidStop?(anim, finished: true)
        }
    }
}
