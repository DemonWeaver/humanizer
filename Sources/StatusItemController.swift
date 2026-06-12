import AppKit
import SwiftUI
import Combine

/// Manual status item + popover instead of SwiftUI's MenuBarExtra, so the
/// menu bar icon itself can accept file drops. The popover dismisses when you
/// click into Finder to grab a file, so the icon is the reliable drop target.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let state: AppState
    private var cancellables: Set<AnyCancellable> = []
    private var lastPopoverClose = Date.distantPast

    init(state: AppState) {
        self.state = state
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = NSSize(width: 440, height: 600)
        popover.contentViewController = NSHostingController(
            rootView: MainView()
                .environmentObject(state)
                .frame(width: 440, height: 600)
        )

        if let button = statusItem.button {
            button.image = MenuBarIcon.normal
            button.toolTip = "Humanizer — drop a file here to humanize it"
            let drop = StatusItemDropView(frame: button.bounds)
            drop.autoresizingMask = [.width, .height]
            drop.onClick = { [weak self] in self?.togglePopover() }
            drop.onFileDrop = { [weak self] url in self?.handleDrop(url) }
            button.addSubview(drop)
        }

        NotificationCenter.default.publisher(for: NSPopover.didCloseNotification, object: popover)
            .sink { [weak self] _ in self?.lastPopoverClose = Date() }
            .store(in: &cancellables)

        state.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleIconUpdate() }
            .store(in: &cancellables)
    }

    private func scheduleIconUpdate() {
        // objectWillChange fires before the value lands; read on the next tick.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            statusItem.button?.image = state.isWorking ? MenuBarIcon.working : MenuBarIcon.normal
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if Date().timeIntervalSince(lastPopoverClose) > 0.25 {
            // If the transient popover closed within the same click (the click
            // outside dismissed it), treat the click as "close", not "reopen".
            show()
        }
    }

    func show() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func handleDrop(_ url: URL) {
        show()
        state.loadDroppedFile(url, autoRun: true)
    }
}

/// Transparent overlay on the status item button that accepts file drags and
/// forwards plain clicks to the toggle action.
final class StatusItemDropView: NSView {
    var onClick: () -> Void = {}
    var onFileDrop: (URL) -> Void = { _ in }

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func mouseDown(with event: NSEvent) {
        onClick()
    }

    private func fileURL(from sender: NSDraggingInfo) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]
        return urls?.first
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let url = fileURL(from: sender),
              TextExtractor.supportedExtensions.contains(url.pathExtension.lowercased()) else {
            return []
        }
        (superview as? NSStatusBarButton)?.highlight(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        (superview as? NSStatusBarButton)?.highlight(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        (superview as? NSStatusBarButton)?.highlight(false)
        guard let url = fileURL(from: sender) else { return false }
        onFileDrop(url)
        return true
    }
}
