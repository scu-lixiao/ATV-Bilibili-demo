//
//  SidxParseUtil.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/11/13.
//

import Foundation

enum SidxParseUtil {
    struct Sidx {
        let timescale: Int
        let firstOffset: Int
        let earliestPresentationTime: Int
        let segments: [SegmentInfo]

        struct SegmentInfo {
            let type: Int
            let size: Int
            let duration: Int
            let sap: Int
            let sap_type: Int
            let sap_delta: Int
        }

        func maxSegmentDuration() -> Int? {
            if let duration = segments.map({ Double($0.duration) / Double(timescale) }).max() {
                return Int(duration + 1)
            }
            return nil
        }
    }

    static func processIndexData(data: Data) -> Sidx? {
        let count = UInt64(data.count)
        var offset: UInt64 = 0
        // 逐个 box 遍历并整体跳过非 sidx 的 box。之前只跳过 8 字节头部，会把 box 内容当成 box 头继续解析，
        // 得到错误的分片表（表现为无限加载）或越界崩溃；version 1 的 64 位字段也按 32 位读错
        while offset + 8 <= count {
            let boxStart = offset
            var size = UInt64(data.getUint32(offset: &offset))
            let type = String(bytes: data.getUint32(offset: &offset).toUInt8s, encoding: .ascii) ?? ""
            if size == 1 {
                // 64 位 largesize
                guard offset + 8 <= count else { return nil }
                size = data.getValue(type: UInt64.self, offset: &offset).bigEndian
            } else if size == 0 {
                // box 一直延伸到数据末尾
                size = count - boxStart
            }
            // 越过数据末尾的 box 之后不可能再有 sidx
            guard size >= offset - boxStart, size <= count - boxStart else { return nil }
            if type == "sidx" {
                return processSIDX(data: Data(data[Int(offset)..<Int(boxStart + size)]))
            }
            offset = boxStart + size
        }
        return nil
    }

    private static func processSIDX(data: Data) -> Sidx? {
        guard data.count >= 4 else { return nil }
        var offset: UInt64 = 0
        let version = data.getUint8(offset: &offset)
        _ = data.getUint8(offset: &offset) // flags
        _ = data.getUint8(offset: &offset) // flags
        _ = data.getUint8(offset: &offset) // flags

        // version 0: 32 位 earliest_presentation_time / first_offset，version 1: 64 位
        let timeFieldsSize = version == 0 ? 8 : 16
        guard data.count >= 8 + timeFieldsSize + 4 else { return nil }
        _ = data.getUint32(offset: &offset) // refID
        let timescale = data.getUint32(offset: &offset)
        let earliest_presentation_time: UInt64
        let first_offset: UInt64
        if version == 0 {
            earliest_presentation_time = UInt64(data.getUint32(offset: &offset))
            first_offset = UInt64(data.getUint32(offset: &offset))
        } else {
            earliest_presentation_time = data.getValue(type: UInt64.self, offset: &offset).bigEndian
            first_offset = data.getValue(type: UInt64.self, offset: &offset).bigEndian
        }
        _ = data.getValue(type: UInt16.self, offset: &offset).bigEndian // reserved
        let reference_count = data.getValue(type: UInt16.self, offset: &offset).bigEndian
        guard UInt64(data.count) >= offset + UInt64(reference_count) * 12 else { return nil }

        var infos = [Sidx.SegmentInfo]()
        for _ in 0..<reference_count {
            var code = data.getUint32(offset: &offset)
            let reference_type = (code >> 31) & 1
            let referenced_size = (code & 0x7fffffff)
            let duration = data.getUint32(offset: &offset)

            code = data.getUint32(offset: &offset)
            let starts_with_SAP = (code >> 31) & 1
            let sap_type = (code >> 29) & 7
            let sap_delta_time = (code & 0x0fffffff)
            let info = Sidx.SegmentInfo(type: Int(reference_type), size: Int(referenced_size), duration: Int(duration), sap: Int(starts_with_SAP), sap_type: Int(sap_type), sap_delta: Int(sap_delta_time))
            infos.append(info)
        }

        return Sidx(timescale: Int(timescale), firstOffset: Int(clamping: first_offset), earliestPresentationTime: Int(clamping: earliest_presentation_time), segments: infos)
    }
}

extension Data {
    func getUint32(offset: inout UInt64) -> UInt32 {
        getValue(type: UInt32.self, offset: &offset).bigEndian
    }

    func getUint8(offset: inout UInt64) -> UInt8 {
        getValue(type: UInt8.self, offset: &offset).bigEndian
    }

    func getValue<T>(type: T.Type, offset: inout UInt64) -> T {
        let size = UInt64(MemoryLayout<T>.size)
        defer {
            offset += size
        }
        return Data(self[offset..<size + offset]).withUnsafeBytes({ $0.load(as: T.self) })
    }
}

protocol UIntToUInt8sConvertable {
    var toUInt8s: [UInt8] { get }
}

extension UIntToUInt8sConvertable {
    func toUInt8Arr<T>(endian: T, count: Int) -> [UInt8] {
        var _endian = endian
        let UInt8Ptr = withUnsafePointer(to: &_endian) {
            $0.withMemoryRebound(to: UInt8.self, capacity: count) {
                UnsafeBufferPointer(start: $0, count: count)
            }
        }
        return [UInt8](UInt8Ptr)
    }
}

extension UInt32: UIntToUInt8sConvertable {
    var toUInt8s: [UInt8] {
        return toUInt8Arr(endian: bigEndian,
                          count: MemoryLayout<UInt32>.size)
    }
}

extension UInt64: UIntToUInt8sConvertable {
    var toUInt8s: [UInt8] {
        return toUInt8Arr(endian: bigEndian,
                          count: MemoryLayout<UInt64>.size)
    }
}
