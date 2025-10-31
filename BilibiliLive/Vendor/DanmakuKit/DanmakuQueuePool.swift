//
//  DanmakuQueuePool.swift
//  DanmakuKit
//
//  Created by Q YiZhong on 2020/8/16.
//

import Foundation

class DanmakuQueuePool {
    public let name: String

    private var queues: [DispatchQueue] = []

    public let queueCount: Int

    // tvOS 26 优化：使用原子操作保护 counter
    private let counterLock = NSLock()
    private var _counter: Int = 0
    
    private var counter: Int {
        get {
            counterLock.lock()
            defer { counterLock.unlock() }
            return _counter
        }
        set {
            counterLock.lock()
            defer { counterLock.unlock() }
            _counter = newValue
        }
    }

    public init(name: String, queueCount: Int, qos: DispatchQoS) {
        self.name = name
        self.queueCount = queueCount
        for i in 0..<queueCount {
            // tvOS 26 优化：为每个队列指定唯一标识，便于调试
            let queue = DispatchQueue(
                label: "\(name).\(i)",
                qos: qos,
                attributes: [],
                autoreleaseFrequency: .workItem, // 优化内存释放频率
                target: nil
            )
            queues.append(queue)
        }
    }

    public var queue: DispatchQueue {
        return getQueue()
    }

    private func getQueue() -> DispatchQueue {
        counterLock.lock()
        if _counter == Int.max {
            _counter = 0
        }
        let index = _counter % queueCount
        _counter += 1
        counterLock.unlock()
        return queues[index]
    }
}
