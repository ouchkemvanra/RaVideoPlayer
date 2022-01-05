//
//  RaPlayerResourceLoadingRequest.swift
//  RaVideoPlayer
//
//  Created by Ouch Kemvanra on 12/30/21.
//

import Foundation
import AVFoundation

public protocol RaPlayerResourceLoadingRequestDelegate: class {
    func resourceLoadingRequest(_ resourceLoadingRequest: RaPlayerResourceLoadingRequest, didCompleteWithError error: Error?)
}

open class RaPlayerResourceLoadingRequest: NSObject {
    
    open fileprivate(set) var request: AVAssetResourceLoadingRequest
    open weak var delegate: RaPlayerResourceLoadingRequestDelegate?
    fileprivate var downloader: RaPlayerDownloader
    
    public init(_ downloader: RaPlayerDownloader, _ resourceLoadingRequest: AVAssetResourceLoadingRequest) {
        self.downloader = downloader
        request = resourceLoadingRequest
        super.init()
        downloader.delegate = self
        fillCacheMedia()
    }
    
    internal func fillCacheMedia() {
        if  downloader.cacheMedia != nil,
            let contentType = downloader.cacheMedia?.contentType {
            if let cacheMedia = downloader.cacheMedia {
                request.contentInformationRequest?.contentType = contentType
                request.contentInformationRequest?.contentLength = cacheMedia.contentLength
                request.contentInformationRequest?.isByteRangeAccessSupported = cacheMedia.isByteRangeAccessSupported
            }
        }
    }
    
    internal func loaderCancelledError() -> Error {
        let nsError = NSError(domain: "com.Raplayer.resourceloader", code: -3, userInfo: [NSLocalizedDescriptionKey: "Resource loader cancelled"])
        return nsError as Error
    }
    
    open func finish() {
        if !request.isFinished {
            request.finishLoading(with: loaderCancelledError())
        }
    }
    
    open func startWork() {
        if let dataRequest = request.dataRequest {
            var offset = dataRequest.requestedOffset
            let length = dataRequest.requestedLength
            if dataRequest.currentOffset != 0 {
                offset = dataRequest.currentOffset
            }
            var isEnd = false
            if #available(iOS 9.0, *) {
                if dataRequest.requestsAllDataToEndOfResource {
                    isEnd = true
                }
            }
            downloader.dowloaderTask(offset, length, isEnd)
        }
    }
    
    open func cancel() {
        downloader.cancel()
    }
}

// MARK: - RaPlayerDownloaderDelegate
extension RaPlayerResourceLoadingRequest: RaPlayerDownloaderDelegate {
    public func downloader(_ downloader: RaPlayerDownloader, didReceiveData data: Data) {
        request.dataRequest?.respond(with: data)
    }
    
    public func downloader(_ downloader: RaPlayerDownloader, didFinishedWithError error: Error?) {
        if error?._code == NSURLErrorCancelled { return }
        
        if (error == nil) {
            request.finishLoading()
        } else {
            request.finishLoading(with: error)
        }
        
        delegate?.resourceLoadingRequest(self, didCompleteWithError: error)
        
    }
    
    public func downloader(_ downloader: RaPlayerDownloader, didReceiveResponse response: URLResponse) {
        fillCacheMedia()
    }
}


