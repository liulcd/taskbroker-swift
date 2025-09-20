// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

public protocol TaskBrokerType: NSObjectProtocol, Sendable {
    var id: AnyHashable { get }
    
    var paths: [AnyHashable] { get }
    var version: UInt { get }
    
    func match(_ path: AnyHashable, parameters: Any?, version: UInt) -> Bool
    
    func run(_ path: AnyHashable, parameters: Any?) async -> (result: Any?, error: NSError?)
}

public extension TaskBrokerType {
    func match(_ path: AnyHashable, parameters: Any?, version: UInt) -> Bool {
        return paths.contains { element in
            element == path
        }
    }
}

private actor TaskBrokerActor {
    private var brokers: [TaskBrokerType] = []
    
    func append(_ broker: TaskBrokerType) {
        if !brokers.contains(where: { element in
            element.id == broker.id
        }) {
            brokers.append(broker)
            brokers.sort { $0.version < $1.version }
        }
    }

    func remove(_ id: AnyHashable) {
        brokers.removeAll { element in
            element.id == id
        }
    }
    
    func match(_ request: TaskBroker.SendableRequest) -> TaskBrokerType? {
        var matchPaths: [TaskBrokerType] = []
        var matchVersions: [TaskBrokerType] = []
        brokers.forEach { element in
            if element.paths.contains(where: { path in
                path == request.path
            }) {
                matchPaths.append(element)
                if element.version == request.version {
                    matchVersions.append(element)
                }
            }
        }
        var broker: TaskBrokerType?
        while matchVersions.count > 0 {
            let lastBroker = matchVersions.removeLast()
            if lastBroker.match(request.path, parameters: request.parameters, version: request.version) {
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
                if lastBroker.match(request.path, parameters: request.parameters, version: request.version) {
                    broker = lastBroker
                    break
                }
            }
        }
        return broker
    }
}

public class TaskBroker: NSObject, @unchecked Sendable {
    private let actor = TaskBrokerActor()
    
    public func append(_ broker: TaskBrokerType) async {
        await actor.append(broker)
    }
    
    public func remove(_ id: AnyHashable) async {
        let hash = SendableHash(value: id)
        await actor.remove(hash.value)
    }
    
    public func publish(_ path: AnyHashable, parameters: Any?, version: UInt = 0) async -> (result: Any?, error: NSError?)? {
        let request = SendableRequest(path: path, parameters: parameters, version: version)
        guard let broker = await actor.match(request) else {
            return nil
        }
        return await broker.run(path, parameters: parameters)
    }
    
    internal class SendableRequest: NSObject, @unchecked Sendable {
        let path: AnyHashable
        let parameters: Any?
        let version: UInt
        
        init(path: AnyHashable, parameters: Any?, version: UInt) {
            self.path = path
            self.parameters = parameters
            self.version = version
        }
    }

    private class SendableHash: NSObject, @unchecked Sendable {
        let value: AnyHashable
        
        init(value: AnyHashable) {
            self.value = value
        }
    }
}

public extension TaskBroker {
    static let main: TaskBroker = TaskBroker()
}

protocol TaskBrokerLoadable {
    dynamic static func loadWobrokers()
}

extension TaskBrokerLoadable {
    dynamic static func loadWobrokers() {
        //Use @_dynamicReplacement(for:) to replace this function.
    }
}
