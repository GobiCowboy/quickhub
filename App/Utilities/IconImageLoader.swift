import AppKit

enum IconImageLoader {
    static func isImageReference(_ name: String) -> Bool {
        isOpenMojiReference(name) || name.hasPrefix("/")
    }

    static func loadImage(named name: String) -> NSImage? {
        if name.hasPrefix("/") {
            return NSImage(contentsOfFile: name)
        }

        guard let openMojiName = normalizedOpenMojiName(from: name) else {
            return nil
        }

        let fileName = (openMojiName as NSString).deletingPathExtension
        let ext = (openMojiName as NSString).pathExtension.isEmpty ? "png" : (openMojiName as NSString).pathExtension

        if let path = Bundle.main.path(forResource: fileName, ofType: ext) {
            return NSImage(contentsOfFile: path)
        }

        if let path = Bundle.main.path(forResource: fileName, ofType: ext, inDirectory: "OpenMoji") {
            return NSImage(contentsOfFile: path)
        }

        if let path = Bundle.main.path(forResource: fileName, ofType: ext, inDirectory: "openmoji") {
            return NSImage(contentsOfFile: path)
        }

        return nil
    }

    private static func isOpenMojiReference(_ name: String) -> Bool {
        name.lowercased().hasPrefix("openmoji/")
    }

    private static func normalizedOpenMojiName(from name: String) -> String? {
        guard isOpenMojiReference(name) else { return nil }
        let prefixLength = "openmoji/".count
        return String(name.dropFirst(prefixLength))
    }
}
