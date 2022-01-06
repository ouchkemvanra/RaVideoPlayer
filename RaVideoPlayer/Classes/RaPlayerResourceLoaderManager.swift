//
//  RaResourceLoaderManager.swift
//  RaVideoPlayer
//
//  Created by Ouch Kemvanra on 12/30/21.
//

import Foundation
import AVFoundation

public protocol RaPlayerResourceLoaderManagerDelegate: class {
    func resourceLoaderManager(_ loadURL: URL, didFailWithError error: Error?)
}

open class RaPlayerResourceLoaderManager: NSObject {
    
    open weak var delegate: RaPlayerResourceLoaderManagerDelegate?
    fileprivate var loaders = Dictionary<String, RaPlayerResourceLoader>()
    fileprivate let kCacheScheme = "RaPlayerMideaCache"
    
    public override init() {
        super.init()
    }
    
    open func cleanCache() {
        loaders.removeAll()
    }
    
    open func cancelLoaders() {
        for (_, value) in loaders {
            value.cancel()
        }
        loaders.removeAll()
    }
    
    internal func key(forResourceLoaderWithURL url: URL) -> String? {
        guard url.absoluteString.hasPrefix(kCacheScheme) else { return nil }
        return url.absoluteString
    }
    
    internal func loader(forRequest request: AVAssetResourceLoadingRequest) -> RaPlayerResourceLoader? {
        guard let requestKey = key(forResourceLoaderWithURL: request.request.url!) else { return nil }
        let loader = loaders[requestKey]
        return loader
    }
    
    open func assetURL(_ url: URL?) -> URL? {
        guard let assetUrl = url else { return nil }
        let assetURL = URL(string: kCacheScheme.appending(assetUrl.absoluteString))
        return assetURL
    }
    
    open func playerItem(_ url: URL) -> AVPlayerItem {
        let assetURL = self.assetURL(url)
        let urlAsset = AVURLAsset(url: assetURL!, options: nil)
        urlAsset.resourceLoader.setDelegate(self, queue: DispatchQueue.main)
        let playerItem = AVPlayerItem(asset: urlAsset)
        if #available(iOS 9.0, *) {
            playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        }
        
        return playerItem
    }
}

// MARK: - AVAssetResourceLoaderDelegate
extension RaPlayerResourceLoaderManager: AVAssetResourceLoaderDelegate {
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        if let resourceURL = loadingRequest.request.url {
            if resourceURL.absoluteString.hasPrefix(kCacheScheme) {
                var loader = self.loader(forRequest: loadingRequest)
                if loader == nil {
                    var originURLString = resourceURL.absoluteString
                    originURLString = originURLString.replacingOccurrences(of: kCacheScheme, with: "")
                    let originURL = URL(string: originURLString)
                    loader = RaPlayerResourceLoader(url: originURL!)
                    loader?.delegate = self
                    let key = self.key(forResourceLoaderWithURL: resourceURL)
                    loaders[key!] = loader
                    // fix https://github.com/vitoziv/VIMediaCache/pull/29
                }
                loader?.add(loadingRequest)
                return true
            }
        }
        return false
    }
    
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        let loader = self.loader(forRequest: loadingRequest)
        loader?.cancel()
        loader?.remove(loadingRequest)
    }
    
}

// MARK: - RaPlayerResourceLoaderDelegate
extension RaPlayerResourceLoaderManager: RaPlayerResourceLoaderDelegate {
    public func resourceLoader(_ resourceLoader: RaPlayerResourceLoader, didFailWithError error: Error?) {
        resourceLoader.cancel()
        delegate?.resourceLoaderManager(resourceLoader.url, didFailWithError: error)
    }
}


