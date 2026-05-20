import AppKit

@main
enum AtmosphereMain {
    @MainActor
    private static let delegate = AppDelegate()

    @MainActor
    static func main() {
        let application = NSApplication.shared
        application.delegate = delegate
        application.run()
    }
}
