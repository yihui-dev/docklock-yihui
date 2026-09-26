import AppKit
import CoreFoundation

/// The running app's end of the CLI channel: a local CFMessagePort answering JSON requests.
final class ControlServer {
    private var port: CFMessagePort?
    private var handler: ((Data) -> Data)?

    /// Returns false if another process already owns the port (another DockLock is running).
    @discardableResult
    func start(handler: @escaping (Data) -> Data) -> Bool {
        self.handler = handler
        var context = CFMessagePortContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        var shouldFree: DarwinBoolean = false
        guard let port = CFMessagePortCreateLocal(nil, DockLockInfo.controlPortName as CFString, { _, _, data, info in
            guard let info else { return nil }
            let server = Unmanaged<ControlServer>.fromOpaque(info).takeUnretainedValue()
            let request = data.map { $0 as Data } ?? Data()
            let reply = server.handler?(request) ?? Data()
            return Unmanaged.passRetained(reply as CFData)
        }, &context, &shouldFree) else {
            return false
        }
        self.port = port
        if let source = CFMessagePortCreateRunLoopSource(nil, port, 0) {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        return true
    }

    func stop() {
        if let port { CFMessagePortInvalidate(port) }
        port = nil
    }
}

/// The CLI's end: sends one request and waits for the reply.
enum ControlClient {
    static var isAppRunning: Bool {
        CFMessagePortCreateRemote(nil, DockLockInfo.controlPortName as CFString) != nil
    }

    static func send(_ request: ControlRequest, timeout: TimeInterval = 10) -> ControlResponse? {
        guard let port = CFMessagePortCreateRemote(nil, DockLockInfo.controlPortName as CFString) else { return nil }
        var reply: Unmanaged<CFData>?
        let status = CFMessagePortSendRequest(port, 0, ControlCodec.encode(request) as CFData, timeout, timeout,
                                              CFRunLoopMode.defaultMode.rawValue, &reply)
        guard status == Int32(kCFMessagePortSuccess), let reply else { return nil }
        let data = reply.takeRetainedValue() as Data
        return ControlCodec.decode(ControlResponse.self, from: data)
    }
}

/// `DockLock.app/Contents/MacOS/DockLock <command>` — the command line interface.
enum CommandLineTool {
    static func run(_ arguments: [String]) -> Int32 {
        switch CLIParser.parse(arguments) {
        case .failure(let error):
            FileHandle.standardError.write(Data("docklock: \(error)\nRun 'docklock help' for usage.\n".utf8))
            return 1
        case .success(let invocation):
            switch invocation.action {
            case .help:
                print(CLIParser.helpText)
                return 0
            case .version:
                print(invocation.json ? "{\"version\":\"\(DockLockInfo.version)\"}" : DockLockInfo.version)
                return 0
            case .launch:
                return launchApp()
            case .command(let command):
                return send(command, json: invocation.json, wait: invocation.wait)
            }
        }
    }

    private static func send(_ command: DockCommand, json: Bool, wait: Bool) -> Int32 {
        guard ControlClient.isAppRunning else {
            if command == .quit {
                print("DockLock is not running.")
                return 0
            }
            FileHandle.standardError.write(Data("DockLock is not running. Start it with: docklock launch\n".utf8))
            return 3
        }
        guard var response = ControlClient.send(.command(command, wait: wait)) else {
            if command == .quit { return 0 } // the app quit before answering
            FileHandle.standardError.write(Data("docklock: no answer from DockLock\n".utf8))
            return 4
        }
        let deadline = Date().addingTimeInterval(30)
        while wait, let job = response.pendingJob, Date() < deadline {
            usleep(150_000)
            guard let next = ControlClient.send(.job(job)) else { return 4 }
            response = next
        }
        if json {
            print(response.json ?? ControlCodec.jsonString(["ok": response.ok ? "true" : "false", "message": response.message]))
        } else if !response.message.isEmpty {
            print(response.message)
        }
        return response.ok ? 0 : 2
    }

    private static func launchApp() -> Int32 {
        if ControlClient.isAppRunning {
            print("DockLock is already running.")
            return 0
        }
        guard let bundleURL = appBundleURL() else {
            FileHandle.standardError.write(Data("docklock: cannot find DockLock.app\n".utf8))
            return 2
        }
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-g", bundleURL.path]
        do { try open.run() } catch { return 2 }
        open.waitUntilExit()
        for _ in 0..<50 {
            if ControlClient.isAppRunning {
                print("DockLock is running.")
                return 0
            }
            usleep(200_000)
        }
        FileHandle.standardError.write(Data("docklock: DockLock did not start\n".utf8))
        return 2
    }

    private static func appBundleURL() -> URL? {
        let executable = URL(fileURLWithPath: Bundle.main.executablePath ?? CommandLine.arguments[0]).resolvingSymlinksInPath()
        var url = executable
        while url.pathComponents.count > 1 {
            if url.pathExtension == "app" { return url }
            url.deleteLastPathComponent()
        }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: DockLockInfo.bundleIdentifier)
    }
}
