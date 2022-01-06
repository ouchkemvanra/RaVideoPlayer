//
//  RaPlayerDownloader.swift
//  RaVideoPlayer
//
//  Created by Ouch Kemvanra on 12/30/21.
//

import Foundation
import MobileCoreServices

// MARK: - RaPlayerDownloaderStatus
public struct RaPlayerDownloaderStatus {
    
    static let shared = RaPlayerDownloaderStatus()
    fileprivate var downloadingURLs: NSMutableSet
    fileprivate let downloaderStatusQueue = DispatchQueue(label: "com.Raplayer.downloaderStatusQueue")
    
    init() {
        downloadingURLs = NSMutableSet()
    }
    
    public func add(URL: URL) {
        downloaderStatusQueue.sync {
            downloadingURLs.add(URL)
        }
    }
    
    public func remove(URL: URL) {
        downloaderStatusQueue.sync {
            downloadingURLs.remove(URL)
        }
    }
    
    public func contains(URL: URL) -> Bool{
        return downloadingURLs.contains(URL)
    }
    
    public func urls() -> NSSet {
        return downloadingURLs.copy() as! NSSet
    }
}

public protocol RaPlayerDownloaderDelegate: class {
    func downloader(_ downloader: RaPlayerDownloader, didReceiveResponse response: URLResponse)
    func downloader(_ downloader: RaPlayerDownloader, didReceiveData data: Data)
    func downloader(_ downloader: RaPlayerDownloader, didFinishedWithError error: Error?)
}


extension RaPlayerDownloaderDelegate {
    public func downloader(_ downloader: RaPlayerDownloader, didReceiveResponse response: URLResponse) { }
    public func downloader(_ downloader: RaPlayerDownloader, didReceiveData data: Data) { }
    public func downloader(_ downloader: RaPlayerDownloader, didFinishedWithError error: Error?) { }
}

// MARK: - RaPlayerDownloader
open class RaPlayerDownloader: NSObject {
    open fileprivate(set) var url: URL
    open weak var delegate: RaPlayerDownloaderDelegate?
    open var cacheMedia: RaPlayerCacheMedia?
    open var cacheMediaWorker: RaPlayerCacheMediaWorker
    
    fileprivate var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration)
        return session
    }()
    fileprivate var isDownloadToEnd: Bool = false
    fileprivate var actionWorker: RaPlayerDownloadActionWorker?
    
    deinit {
        RaPlayerDownloaderStatus.shared.remove(URL: url)
    }
    
    public init(url: URL) {
        self.url = url
        cacheMediaWorker = RaPlayerCacheMediaWorker(url: url)
        cacheMedia = cacheMediaWorker.cacheConfiguration?.cacheMedia
        super.init()
    }
    
    open func dowloaderTask(_ fromOffset: Int64, _ length: Int, _ isEnd: Bool) {
        if isCurrentURLDownloading() {
            handleCurrentURLDownloadingError()
            return
        }
        RaPlayerDownloaderStatus.shared.add(URL: self.url)
        
        var range = NSRange(location: Int(fromOffset), length: length)
        if isEnd {
            if let contentLength = cacheMediaWorker.cacheConfiguration?.cacheMedia?.contentLength {
                range.length = Int(contentLength) - range.location
            } else {
                range.length = 0 - range.location
            }
            
        }
        let actions = cacheMediaWorker.cachedDataActions(forRange: range)
        actionWorker = RaPlayerDownloadActionWorker(actions: actions, url: url, cacheMediaWorker: cacheMediaWorker)
        actionWorker?.delegate = self
        actionWorker?.start()
    }
    open func dowloadFrameStartToEnd() {
        if isCurrentURLDownloading() {
            handleCurrentURLDownloadingError()
            return
        }
        RaPlayerDownloaderStatus.shared.add(URL: url)
        
        isDownloadToEnd = true
        let range = NSRange(location: 0, length: 2)
        let actions = cacheMediaWorker.cachedDataActions(forRange: range)
        actionWorker = RaPlayerDownloadActionWorker(actions: actions, url: url, cacheMediaWorker: cacheMediaWorker)
        actionWorker?.delegate = self
        actionWorker?.start()
        
        
    }
    open func cancel() {
        RaPlayerDownloaderStatus.shared.remove(URL: url)
        actionWorker?.cancel()
        actionWorker?.delegate = nil
        actionWorker = nil
    }
    
    open func invalidateAndCancel() {
        RaPlayerDownloaderStatus.shared.remove(URL: url)
        actionWorker?.cancel()
        actionWorker?.delegate = nil
        actionWorker = nil
    }
    
    // check
    internal func isCurrentURLDownloading() -> Bool {
        return RaPlayerDownloaderStatus.shared.contains(URL: url)
    }
    
    internal func handleCurrentURLDownloadingError() {
        
        if isCurrentURLDownloading() {
            let userInfo = [NSLocalizedDescriptionKey: "URL: \(url) alreay in downloading queue."]
            let error = NSError(domain: "com.Raplayer.download", code: -1, userInfo: userInfo)
            delegate?.downloader(self, didFinishedWithError: error as Error)
        }
    }
}

// MARK: - RaPlayerDownloadActionWorkerDelegate
extension RaPlayerDownloader: RaPlayerDownloadActionWorkerDelegate {
    
    public func downloadActionWorker(_ actionWorker: RaPlayerDownloadActionWorker, didFinishWithError error: Error?) {
        RaPlayerDownloaderStatus.shared.remove(URL: url)
        if error == nil && isDownloadToEnd {
            isDownloadToEnd = false
            let length = (cacheMediaWorker.cacheConfiguration?.cacheMedia?.contentLength)! - 2
            dowloaderTask(2, Int(length), true)
        } else {
            delegate?.downloader(self, didFinishedWithError: error)
        }
    }
    
    public func downloadActionWorker(_ actionWorker: RaPlayerDownloadActionWorker, didReceive data: Data, isLocal: Bool) {
        delegate?.downloader(self, didReceiveData: data)
    }
    
    public func downloadActionWorker(_ actionWorker: RaPlayerDownloadActionWorker, didReceive response: URLResponse) {
        if cacheMedia == nil {
            let cacheMedia = RaPlayerCacheMedia()
            if response.isKind(of: HTTPURLResponse.classForCoder()) {
                
                let HTTPurlResponse = response as! HTTPURLResponse                                  // set header
                let acceptRange = HTTPurlResponse.allHeaderFields["Accept-Ranges"] as? String
                if let bytes = acceptRange?.isEqual("bytes") {
                    cacheMedia.isByteRangeAccessSupported = bytes
                }
                // fix swift allHeaderFields NO! case insensitive
                let contentRange = HTTPurlResponse.allHeaderFields["content-range"] as? String
                let contentRang = HTTPurlResponse.allHeaderFields["Content-Range"] as? String
                if let last = contentRange?.components(separatedBy: "/").last {
                    cacheMedia.contentLength = Int64(last)!
                }
                if let last = contentRang?.components(separatedBy: "/").last {
                    cacheMedia.contentLength = Int64(last)!
                }
                
            }
            if let mimeType = response.mimeType {
                let contentType =  UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)
                if let takeUnretainedValue = contentType?.takeUnretainedValue() {
                    cacheMedia.contentType = takeUnretainedValue as String
                }
            }
            self.cacheMedia = cacheMedia
            let isSetCacheMedia = cacheMediaWorker.set(cacheMedia: cacheMedia)
            if !isSetCacheMedia {
                let nsError = NSError(domain: "com.Raplayer.cacheMedia", code: -1, userInfo: [NSLocalizedDescriptionKey:"Set cache media failed."])
                delegate?.downloader(self, didFinishedWithError: nsError as Error)
                return
            }
        }
        delegate?.downloader(self, didReceiveResponse: response)
    }
    
    
}

