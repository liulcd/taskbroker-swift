// The Swift Programming Language
// https://docs.swift.org/swift-book

// TaskBroker: A lightweight, extensible task broker for Swift
// https://github.com/liulcd/taskbroker-swift
//
// This file defines the core protocol and implementation for a task broker system,
// allowing you to register, match, and execute tasks asynchronously by path and version.
//
// Author: liulcd
// License: MIT

import Foundation
import SendableValue

/// Protocol for a task broker. Implement this to register your own task handlers.
public protocol TaskBrokerType: NSObjectProtocol, Sendable {
    /// Unique identifier for the broker instance.
    var id: AnyHashable { get }
    /// Supported task paths.
    var paths: [AnyHashable] { get }
    /// Version of the broker implementation.
    var version: UInt { get }
    /// Determines if this broker can handle a given path, parameters, and version.
    func match(_ path: AnyHashable, parameters: Any?, version: UInt) -> Bool
    /// Executes the task asynchronously for the given path and parameters.
    func run(_ path: AnyHashable, parameters: Any?) async -> (result: Any?, error: NSError?)
}


public extension TaskBrokerType {
    /// Default implementation: matches if the path is in the supported paths.
    func match(_ path: AnyHashable, parameters: Any?, version: UInt) -> Bool {
        return paths.contains { element in
            element == path
        }
    }
}


/// Internal actor to manage broker registration and matching.
private actor TaskBrokerActor {
    private var brokers: [TaskBrokerType] = []
    /// Register a new broker if not already present.
    func append(_ broker: TaskBrokerType) {
        if !brokers.contains(where: { element in
            element.id == broker.id
        }) {
            brokers.append(broker)
            brokers.sort { $0.version < $1.version }
        }
    }
    /// Remove a broker by its id.
    func remove(_ id: AnyHashable) {
        brokers.removeAll { element in
            element.id == id
        }
    }
    /// Find a broker that matches the request by path and version.
    func match(_ path: AnyHashable, parameters: Any?, version: UInt) -> TaskBrokerType? {
        var matchPaths: [TaskBrokerType] = []
        var matchVersions: [TaskBrokerType] = []
        brokers.forEach { element in
            if element.paths.contains(where: { pathElement in
                pathElement == path
            }) {
                matchPaths.append(element)
                if element.version == version {
                    matchVersions.append(element)
                }
            }
        }
        var broker: TaskBrokerType?
        while matchVersions.count > 0 {
            let lastBroker = matchVersions.removeLast()
            if lastBroker.match(path, parameters: parameters, version: version) {
                broker = lastBroker
                break
            }
            matchPaths.removeAll { element in
                element.isEqual(lastBroker)
            }
        }
        if broker == nil {
            while matchPaths.count > 0 {
                let lastBroker = matchPaths.removeLast()
                if lastBroker.match(path, parameters: parameters, version: version) {
                    broker = lastBroker
                    break
                }
            }
        }
        return broker
    }
}


/// Main class for managing and dispatching tasks to registered brokers.
public class TaskBroker: NSObject, @unchecked Sendable {
    private let actor = TaskBrokerActor()
    /// Register a broker instance.
    public func append(_ broker: TaskBrokerType) async {
        await actor.append(broker)
    }
    
    /// Register a broker instance.
    public func append(_ broker: TaskBrokerType) {
        Task {
            await actor.append(broker)
        }
    }
    
    /// Remove a broker by its id.
    public func remove(_ id: AnyHashable) async {
        let hash = SendableAnyHashableValue(id)
        await actor.remove(hash.value)
    }
    
    /// Remove a broker by its id.
    public func remove(_ id: AnyHashable) {
        let hash = SendableAnyHashableValue(id)
        Task {
            await actor.remove(hash.value)
        }
    }
    
    /// Publish a task to the broker system. Returns the result and error if any.
    public func publish(_ path: AnyHashable, parameters: Any?, version: UInt = 0) async -> (result: Any?, error: NSError?)? {
        let path = SendableAnyHashableValue(path)
        let parameters = SendableValue(parameters)
        guard let broker = await actor.match(path.value, parameters: parameters.value, version: version) else {
            return nil
        }
        return await broker.run(path, parameters: parameters)
    }
    
    /// Publish a task to the broker system. Returns the result and error if any.
    public func publish(_ path: AnyHashable, parameters: Any?, version: UInt = 0, result: ((_ result: Any?, _ error: NSError?) -> Void)? = nil) {
        let path = SendableAnyHashableValue(path)
        let parameters = SendableValue(parameters)
        let result = SendableValue(result)
        Task {
            let result = result.resultHandlerValue
            guard let broker = await actor.match(path.value, parameters: parameters.value, version: version) else {
                result?(nil, nil)
                return
            }
            let runResult =  await broker.run(path, parameters: parameters)
            result?(runResult.result, runResult.error)
        }
    }
}


public extension TaskBroker {
    /// Shared singleton instance for convenience.
    static let main: TaskBroker = TaskBroker()
}


/// Protocol for dynamic broker loading (for advanced use).
protocol TaskBrokerLoadable {
    dynamic static func loadWobrokers()
}

extension TaskBrokerLoadable {
    dynamic static func loadWobrokers() {
        // Use @_dynamicReplacement(for:) to replace this function.
    }
}
