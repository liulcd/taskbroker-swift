# TaskBroker

TaskBroker-Swift is a lightweight, extensible task broker framework for Swift. It allows you to register, match, and execute tasks asynchronously by path and version, making it easy to decouple task producers and consumers in your application.

## Features
- Register custom task brokers with unique paths and versions
- Asynchronous task dispatching and result handling
- Simple protocol-based extension
- Thread-safe and actor-based implementation

## Installation

Add the following to your `Package.swift`:

```swift
.package(url: "https://github.com/liulcd/taskbroker-swift.git", from: "1.0.0")
```

## Usage

### 1. Implement a Task Broker

```swift
import TaskBroker

class MyTaskBroker: NSObject, TaskBrokerType {
	let id: AnyHashable = "my-broker"
	let paths: [AnyHashable] = ["echo"]
	let version: UInt = 1

	func match(_ path: AnyHashable, parameters: Any?, version: UInt) -> Bool {
		// Optionally add custom matching logic
		return paths.contains { $0 == path }
	}

	func run(_ path: AnyHashable, parameters: Any?) async -> (result: Any?, error: NSError?) {
		if path == "echo", let text = parameters as? String {
			return ("Echo: \(text)", nil)
		}
		return (nil, NSError(domain: "MyTaskBroker", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found"]))
	}
}
```

### 2. Register and Use the Broker

```swift
let broker = MyTaskBroker()
await TaskBroker.main.append(broker)

let result = await TaskBroker.main.publish("echo", parameters: "Hello, world!", version: 1)
if let (output, error) = result {
	if let output = output as? String {
		print(output) // Echo: Hello, world!
	} else if let error = error {
		print("Error: \(error.localizedDescription)")
	}
}
```

## License

MIT
