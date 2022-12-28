///
/// file-organizer
///
/// Moves files in the downloads folder to a subfolder when they readched a certain age (--days-to-stay).
///
import ArgumentParser
import Foundation
import Glob

let fm = FileManager.default
var ObjCTrue: ObjCBool = true
var ObjCFalse: ObjCBool = false

let targetFolderDateFormat = "YYYY-MM"
let targetFolderMatch = "\\d{4}-\\d{2}"

extension String {
    func matches(_ regex: String) -> Bool {
        return range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
}

@main
struct CleanupFolder: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Collect files from the --root-folder and move them into a subfolder with the format YYYY-MM. Only files that are older than --days-to-stay will be collected.")
    
    @Option(name: .shortAndLong, help: "The root folder.")
    var rootFolder: String
    
    @Option(name: .shortAndLong, help: "How many days to leave files in the root folder before moving.")
    var daysToStay: Int
    
    @Flag(name: .long, help: "Show whats going on.")
    var debug: Bool = false
}

extension CleanupFolder {
    ///
    /// Debug message handler. Enabled with the `--debug` cli argument.
    ///
    func message(_ message: String) {
        if self.debug {
            print(message)
        }
    }
    
    ///
    /// Validate the given root folder and make sure it exists and is writeable.
    /// - Parameter path: The absolute path to the root folder. `~` is automatically expanded.
    ///
    func prepareRootFolder(path: String) throws -> URL {
        // Expand ~ to the users home directory
        var folder = path.replacingOccurrences(of: "~", with: fm.homeDirectoryForCurrentUser.path)
        
        // Make sure the root folder exists
        guard fm.fileExists(atPath: folder, isDirectory: &ObjCTrue) else {
            throw CleanExit.message("Root folder '\(self.rootFolder)' does not exist or is no directory.")
        }
        
        // Make sure we have permission to write to that folder
        guard fm.isWritableFile(atPath: folder) else {
            throw CleanExit.message("Root folder '\(self.rootFolder)' is not writable.")
        }
        // Make sure the root folder ends with a slash
        if !folder.hasSuffix("/") {
            folder = "\(folder)/"
        }
        
        // Make a URL object out of the folder path
        return URL(filePath: folder)
    }
    
    ///
    /// Collect all files suitable to move into the subfolder. Files which were created within the `--days-to-stay`
    /// time window are kept in the root folder.
    ///
    /// - Parameter fromFolder: The folder to collect files from.
    ///
    func collectFiles(fromFolder folder: URL) throws -> [URL] {
        var filesToMove: [URL] = []
        let dateLimit = Date(timeIntervalSinceNow: Double(0 - (daysToStay * 24 * 60 * 60))) // In Seconds
        let files = Glob(pattern: "\(folder.path())*")
        
        self.message("Will move files created earlier than: \(dateLimit.formatted())")
        self.message("Collecting files in folder: \(folder.path())")
        
        for file in files {
            // Skip these folders so we don't put a target directory into another one
            if file.matches(targetFolderMatch) {
                self.message("Skip target directory \(file)")
                continue
            }
            
            // Only move files which have been created earlier than <daysToStay> ago
            let fileURL = URL(filePath: file)
            var fileDate = Date()
            
            // Try to fetch the creation date from the file, otherwise fallback to 'now' above.
            fileDate = try fileURL.resourceValues(forKeys: [.addedToDirectoryDateKey]).addedToDirectoryDate!
           
            if fileDate > dateLimit {
                self.message("File is not old enough to move: \(fileURL.path()) Created at: \(fileDate.formatted())")
                continue
            }
            
            // Any file object left is going to be moved to a target folder
            self.message("Possible file to move: \(fileURL.path()) Created at: \(fileDate.formatted())")
            filesToMove.append(fileURL)
        }
        
        return filesToMove
    }
    
    ///
    /// Move the collected files to a sub-folder in the format YYYY-MM.
    ///
    /// - Parameter filesToMove: A list of files
    /// - Parameter targetFolder: The parent folder where the sub-folder is created.
    ///
    func moveFiles(filesToMove files: [URL], targetFolder: URL) throws -> Int {
        // Format of the target folder is ./YYYY-MM
        let df = DateFormatter()
        df.dateFormat = targetFolderDateFormat

        let targetFolder = targetFolder.appending(path: df.string(for: Date())!)
        
        self.message("Target Folder: \(targetFolder)")
        
        do {
            if !fm.fileExists(atPath: targetFolder.path(), isDirectory: &ObjCTrue) {
                try fm.createDirectory(at: targetFolder, withIntermediateDirectories: false)
            } else {
                self.message("Target folder \(targetFolder.path()) already exists.")
            }
        } catch {
            throw ValidationError("Unable to create target folder. Reason: \(error)")
        }
        
        var filesMoved = 0
        
        for file: URL in files {
            let fileName = file.pathComponents.last!
            let targetFile = targetFolder.appendingPathComponent(fileName)
            
            self.message("About to move file from: \(file.path())\n↳ to: \(targetFile.path())")
            
            // If a file with the same name already exists, remove it first.
            if fm.fileExists(atPath: targetFile.path()) {
                self.message("↳ File in target folder already exists.")
                do {
                    try fm.removeItem(atPath: targetFile.path())
                } catch {
                    self.message("↳ Error removing file from target folder: \(error)")
                }
            }
            
            try fm.moveItem(at: file, to: targetFile)
            filesMoved += 1
            self.message("↳ OK")
        }
        
        return filesMoved
    }
        
    mutating func run() throws {
        let folder: URL = try self.prepareRootFolder(path: self.rootFolder)
        let filesToMove: [URL] = try self.collectFiles(fromFolder: folder)
        if filesToMove.isEmpty {
            throw CleanExit.message("Currently no files to move. Bye 👋")
        }
        let filesMoved: Int = try self.moveFiles(filesToMove: filesToMove, targetFolder: folder)
        throw CleanExit.message("\(filesMoved) file(s) were moved. Bye 👋")
    }
}
