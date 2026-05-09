import AppKit
import Foundation
import ScreenCaptureKit

/// Lightweight, value-type snapshots of the things we can record. We don't
/// pass `SCDisplay` / `SCWindow` directly to the UI because they have to be
/// re-fetched fresh before `SCContentFilter` is built anyway.
public struct DisplayInfo: Identifiable, Hashable, Sendable {
    public let id: CGDirectDisplayID
    public let width: Int
    public let height: Int
    public let frame: CGRect
    public var displayName: String {
        "Display \(id) — \(width)×\(height)"
    }
}

public struct WindowInfo: Identifiable, Hashable, Sendable {
    public let id: CGWindowID
    public let title: String
    public let appName: String
    public let bundleIdentifier: String?
    public let frame: CGRect
    public var displayName: String {
        title.isEmpty ? appName : "\(appName) — \(title)"
    }
}

public struct AppInfo: Identifiable, Hashable, Sendable {
    public let id: pid_t              // processID
    public let bundleIdentifier: String
    public let applicationName: String
    public var displayName: String { applicationName }
}

public struct ShareableContent: Sendable {
    public let displays: [DisplayInfo]
    public let windows:  [WindowInfo]
    public let apps:     [AppInfo]
}

public enum ShareableContentLoader {
    /// Async wrapper around `SCShareableContent.current` that returns
    /// UI-friendly snapshots. Filters out tiny / off-screen / our-own windows.
    public static func load(excludingBundleID ourBundleID: String) async throws -> ShareableContent {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        let displays = content.displays.map {
            DisplayInfo(
                id: $0.displayID,
                width: $0.width,
                height: $0.height,
                frame: $0.frame
            )
        }

        let windows = content.windows
            .filter { $0.owningApplication?.bundleIdentifier != ourBundleID }
            .filter { $0.frame.width >= 40 && $0.frame.height >= 40 }
            .filter { ($0.title ?? "").isEmpty == false || $0.owningApplication != nil }
            .map {
                WindowInfo(
                    id: $0.windowID,
                    title: $0.title ?? "",
                    appName: $0.owningApplication?.applicationName ?? "Unknown",
                    bundleIdentifier: $0.owningApplication?.bundleIdentifier,
                    frame: $0.frame
                )
            }

        let appsByPID = Dictionary(grouping: content.windows.compactMap { $0.owningApplication },
                                   by: { $0.processID })
        let apps = appsByPID.values.compactMap { group -> AppInfo? in
            guard let first = group.first,
                  first.bundleIdentifier != ourBundleID else { return nil }
            return AppInfo(
                id: first.processID,
                bundleIdentifier: first.bundleIdentifier,
                applicationName: first.applicationName
            )
        }
        .sorted { $0.applicationName.lowercased() < $1.applicationName.lowercased() }

        return ShareableContent(displays: displays, windows: windows, apps: apps)
    }

    /// Re-fetch the underlying `SCDisplay` / `SCWindow` / `SCRunningApplication`
    /// objects for a given UI selection. SCK requires you to use a fresh copy
    /// every time you build a filter.
    public static func resolve(
        displayID: CGDirectDisplayID
    ) async throws -> SCDisplay? {
        let content = try await SCShareableContent.current
        return content.displays.first { $0.displayID == displayID }
    }

    public static func resolve(
        windowID: CGWindowID
    ) async throws -> SCWindow? {
        let content = try await SCShareableContent.current
        return content.windows.first { $0.windowID == windowID }
    }

    public static func resolve(
        appPID: pid_t
    ) async throws -> (SCRunningApplication, SCDisplay)? {
        let content = try await SCShareableContent.current
        guard let app = content.applications.first(where: { $0.processID == appPID }),
              let display = content.displays.first else { return nil }
        return (app, display)
    }
}
