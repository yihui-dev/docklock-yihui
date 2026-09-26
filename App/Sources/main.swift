import AppKit

// The same executable is both the menu bar app and the `docklock` command line tool:
// `DockLock.app/Contents/MacOS/DockLock status` (or a `docklock` symlink to it) runs the CLI.
let arguments = Array(CommandLine.arguments.dropFirst())
let invokedAsCLI = URL(fileURLWithPath: CommandLine.arguments.first ?? "").lastPathComponent == "docklock"
if CLIParser.looksLikeCLI(arguments) || (invokedAsCLI && !arguments.isEmpty) {
    exit(CommandLineTool.run(arguments))
}
if invokedAsCLI {
    print(CLIParser.helpText)
    exit(0)
}

let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.run()
