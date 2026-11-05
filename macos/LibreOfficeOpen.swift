// Native Apple-event -> LibreOffice command-line bridge. No shell or keyboard hooks.
import AppKit
import CoreServices
import UniformTypeIdentifiers

let nativeID = "org.libreoffice.script"
let bridgeID = "org.ahmelkholy.libreoffice.open"

// These modes are used by the installer; they do not start a GUI application.
let cli = CommandLine.arguments
if cli.count >= 3 && cli[1] == "--handler" {
    guard let type = UTType(filenameExtension: cli[2]) else { exit(2) }
    let current = LSCopyDefaultRoleHandlerForContentType(type.identifier as CFString, .all)?.takeRetainedValue()
    print(type.identifier + "\t" + ((current as String?) ?? ""))
    exit(0)
}
if cli.count == 4 && cli[1] == "--set-handler" {
    let result = LSSetDefaultRoleHandlerForContentType(cli[2] as CFString, .all, cli[3] as CFString)
    if result != noErr { fputs("Cannot set file association: \(result)\n", stderr) }
    exit(result == noErr ? 0 : 1)
}

class Opener: NSObject, NSApplicationDelegate {
    private var receivedFiles = false
    private var generation = 0
    private var children: [Process] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
            if !receivedFiles { forward([]) }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        receivedFiles = true
        forward(urls)
    }

    func fail(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "LibreOffice could not open the document"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
        NSApp.terminate(nil)
    }

    func forward(_ urls: [URL]) {
        guard urls.allSatisfy({ $0.isFileURL && FileManager.default.fileExists(atPath: $0.path) }) else {
            fail("One of the selected files no longer exists. Select the file again in Finder.")
            return
        }
        let installed = Bundle.main.object(forInfoDictionaryKey: "LibreOfficeApplicationPath") as? String
        let candidates = [installed, "/Applications/LibreOffice.app",
                          NSHomeDirectory() + "/Applications/LibreOffice.app"].compactMap { $0 }
        guard let appPath = candidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0 + "/Contents/MacOS/soffice")
        }) else {
            fail("Install LibreOffice in Applications, then run Repair LibreOffice.command from your settings folder.")
            return
        }
        generation += 1
        let request = generation
        let child = Process()
        child.executableURL = URL(fileURLWithPath: appPath + "/Contents/MacOS/soffice")
        child.arguments = ["--nologo"] + urls.map { $0.absoluteString }
        child.standardInput = FileHandle.nullDevice
        child.standardOutput = FileHandle.nullDevice
        child.standardError = FileHandle.nullDevice
        do {
            try child.run()
            children.append(child)
            activate(request: request, attempts: 0)
        } catch {
            fail(error.localizedDescription)
        }
    }

    func activate(request: Int, attempts: Int) {
        guard request == generation else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [self] in
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: nativeID).first {
                app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                // Allow queued Finder events to reach this process before it exits.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
                    if request == generation { NSApp.terminate(nil) }
                }
            } else if attempts < 119 {
                activate(request: request, attempts: attempts + 1)
            } else {
                fail("LibreOffice did not start within 30 seconds. Run the Doctor task in the Keys workspace for diagnostics. Open documents were not closed.")
            }
        }
    }
}

let app = NSApplication.shared
let opener = Opener()
app.delegate = opener
app.run()
