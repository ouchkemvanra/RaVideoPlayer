//
//  RaPlayerView.swift
//  RaVideoPlayer
//
//  Created by Ouch Kemvanra on 12/30/21.
//


import UIKit
import AVFoundation
import AVKit
public enum SpeedType{
    case slow
    case normal
    case fast
}
public enum QualityType : String{
    case low = "240"
    case normal = "360"
    case high = "720"
    
    var value: String{
        return rawValue
    }
}
public protocol PlayerOptionControl: NSObjectProtocol{
    func changeSpeed(type: SpeedType)
    func changeQuality(type: QualityType)
}
public final class VideoLink{
    var link: String
    var title: String
    var qualityList: [VideoQuality]
    public init(link: String, title: String, qualityList: [VideoQuality]) {
        self.link = link
        self.title = title
        self.qualityList = qualityList
    }
}
public final class VideoQuality{
    var link: String
    var quality: String
    var isSelected: Bool
    public init(link: String, quality: String){
        self.link = link
        self.quality = quality
        self.isSelected = false
    }
}
public protocol PlayerDelegate: AnyObject{
    func didTapOnOption()
    func didFinishPlaying()
}
public enum RaPlayerBufferstate: Int {
    case none           // default
    case readyToPlay
    case buffering
    case stop
    case bufferFinished
}
enum SeekingDirection{
    case left
    case right
}
public final class ImageConfiguration{
    var playImg: UIImage
    var pauseImg: UIImage
    var replayImg: UIImage
    var nextImg: UIImage
    var previousImg: UIImage
    var rewindImg: UIImage
    var forwardImage: UIImage
    var thumbImg: UIImage
    var optionImg: UIImage
    var airplayImg: UIImage
    var fullScreenImg: UIImage
    var exitFullScreenImg: UIImage
    public init(playImg: UIImage, pauseImg: UIImage, replayImg: UIImage, nextImg: UIImage, previousImg: UIImage, rewindImg: UIImage, forwardImage: UIImage, thumbImg: UIImage, optionImg: UIImage, airplayImg: UIImage, fullScreenImg: UIImage, exitFullScreenImg: UIImage){
        self.playImg = playImg
        self.pauseImg = pauseImg
        self.replayImg = replayImg
        self.nextImg = nextImg
        self.previousImg = previousImg
        self.rewindImg = rewindImg
        self.forwardImage = forwardImage
        self.thumbImg = thumbImg
        self.optionImg = optionImg
        self.airplayImg = airplayImg
        self.fullScreenImg = fullScreenImg
        self.exitFullScreenImg = exitFullScreenImg
    }
}
public class RaCoverOptionConfig{
    var speed: SpeedType = .normal
    var quality: QualityType = .normal
}

public final class RaVideoPlayerView: UIView{
    //MARK: ------ State -------
    public var bufferState : RaPlayerBufferstate = .none {
        didSet {
            self.playViewBufferStateChanged(bufferState)
        }
    }
    public var bufferInterval : TimeInterval = 2.0
    public var isFullScreen: Bool = false{
        didSet{
            self.fullScreenButton.isSelected = isFullScreen
        }
    }
    public var viewFrame: CGRect = CGRect()
    public var parentView: UIView?
    
    //MARK: ------ Constant ------
    let bigButtonSize: CGFloat = 50
    let mediumButtonSize: CGFloat = 40
    let smallButtonSize: CGFloat = 30
    
    let buttonSpace: CGFloat = 20
    let smallSpace: CGFloat = 10
    let mediumSpace: CGFloat = 20
    
    let sliderThumbnailWidth: CGFloat = 100
    
    let tapSeekSeconds: CGFloat = 15
    var isScrolling: Bool = false
    var startPlaying: Bool = false
    
    /// Config
    public var isAutoPlay: Bool = false
    var optionConfig = RaCoverOptionConfig()
    var imageConfig: ImageConfiguration!
    private var rate: Float?{
        didSet{
            guard let rate = rate, let player = player, rate != player.rate else {return}
            self.player?.rate = rate
        }
    }
    
    //MARK: ------ Layout -------
    var loadingView: UIActivityIndicatorView!
    ///Slider
    var slider: RaProgressBar!
    var sliderThumbnail: RaSliderThumbnail!
    ///View
    var bgView: UIView!
    var seekingThumbnail: UIView!
    var playerView: UIView!
    var seekingForwardView: RaSeekingView!
    var seekingBackwardView: RaSeekingView!
    
    ///Label
    var timeLabel: UILabel!
    var seekingTimeLabel: UILabel!
    
    ///Button
    var playButton: UIButton!
    var nextButton: UIButton!
    var previousButton: UIButton!
    var rewindButton: UIButton!
    var forwardButton: UIButton!
    
    var optionButton: UIButton!
    var picInPicButton: UIButton!
    var fullScreenButton: UIButton!
    
    // Quality List
    var videoList: [VideoLink] = []
    var qualityList: [VideoQuality] = []
    var selectedVideo: VideoLink?
    
    var secondToResume: Double? = nil
    
    //MARK: ------ Player ------
    fileprivate var resourceLoaderManager = RaPlayerResourceLoaderManager()
    var player: AVPlayer!
    var playerItem: AVPlayerItem!{
        didSet{
            if let old = oldValue{
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: old)
                self.player?.pause()
                self.player = nil
            }
            // Todo : check next previous button
            self.checkNextPrevious()
            
        }
    }
    var playerAsset: AVAsset!
    var playerLayer: AVPlayerLayer!
    @available(iOS 11.0, *)
    private lazy var routePickerView: AVRoutePickerView = {
        let routePickerView = AVRoutePickerView(frame: .zero)
        routePickerView.isHidden = true
        addSubview(routePickerView)
        return routePickerView
    }()
    
    //MARK: ------ Constraint
    var superViewConstraint: [NSLayoutConstraint] = []
    var topButtonConstraint: [NSLayoutConstraint] = []
    var baseConstraint: [NSLayoutConstraint] = []
    var pulseArray : [CAShapeLayer] = []
    
    //MARK: ------ Delegate
    public weak var delegate: PlayerDelegate?
    
    //MARK: ------ Life Cycle ------
    override init(frame: CGRect) {
        super.init(frame: frame)
        
    }
    
    public convenience init(list: [VideoLink], frame: CGRect, playAt: Int = 0, imageConfig: ImageConfiguration) {
        self.init(frame: frame)
        self.imageConfig = imageConfig
        self.videoList = list
        self.selectedVideo = list[playAt]
        self.setup()
    }
    private func setup(){
        setViewLayout()
        setPlayer()
        setSeekingAnimationView()
        addDeviceOrientationNotifications()
    }
    deinit{
        removeObserve()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        showHideControl(self.bgView.alpha == 0)
    }
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
    }
    public override func layoutSubviews() {
        super.layoutSubviews()
        self.playerLayer.frame = playerView.bounds
    }
}
private var playerItemContext = 0

// MARK: - Option Control
extension RaVideoPlayerView: PlayerOptionControl{
    public func changeSpeed(type: SpeedType) {
        switch type {
            case .slow:
                rate = 0.5
                break
            case .normal:
                rate = 1
                break
            case .fast:
                rate = 2
                break
        }
    }
    
    public func changeQuality(type: QualityType) {
        guard let index = selectedVideo?.qualityList.firstIndex(where: {$0.quality == type.value}) else {return}
        guard let link = self.selectedVideo?.qualityList[index].link else {return}
        guard self.selectedVideo?.qualityList[index].isSelected == false else {return}
        self.selectedVideo?.link = link
        self.selectedVideo?.qualityList[index].isSelected = true
        self.secondToResume = self.player.currentItem?.currentTime().seconds
        self.setPlayer()
    }
}

//MARK: - AVPlayer
extension RaVideoPlayerView{
    private func setPlayer(){
        let options = NSKeyValueObservingOptions([.new, .initial])
        guard let video = selectedVideo?.link else {return}
        self.startPlaying = false
        let url = URL.init(string: video)
        playerAsset = AVAsset.init(url: url!)
        playerItem = resourceLoaderManager.playerItem(url!)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.new, .old], context: nil)
        player = AVPlayer.init(playerItem: playerItem)
        player.addObserver(self, forKeyPath: "rate", options: NSKeyValueObservingOptions(), context: nil)
        playerItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges), options: options, context: &playerItemContext)
        playerItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.isPlaybackBufferEmpty), options: options, context: &playerItemContext)
        guard let item = self.playerItem else { return }
        NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinishPlaying),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item)
        player.addPeriodicTimeObserver(forInterval: .init(seconds: 1, preferredTimescale: 1), queue: nil, using: {[weak self] time in
            self?.updateTimeLabel()
            self?.updateSliderBar()
        })
        playButton.isSelected = false
        player.play()
        playerLayer = .init(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.frame = frame
        playerView.layer.masksToBounds = true
        
        if let count = playerView.layer.sublayers, count.count > 1{
            playerLayer.frame = .init(x: 0, y: 0, width: frame.width, height: frame.height)
            playerView.layer.sublayers?.remove(at: 0)
        } else{
            viewFrame = frame
        }
        playerView.layer.insertSublayer(playerLayer, at: 0)
        playerView.layoutIfNeeded()
        if let second = self.secondToResume{
            self.player.seek(to: CMTime.init(seconds: second, preferredTimescale: 1))
        }
    }
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.isPlaybackBufferEmpty){
            if let playbackBufferEmpty = change?[.newKey] as? Bool {
                if playbackBufferEmpty {
                   showloading()
                } else{
                   hideloading()
                }
            }
        } else if keyPath == #keyPath(AVPlayerItem.loadedTimeRanges) {
            
            let loadedTimeRanges = player.currentItem?.loadedTimeRanges
            if let bufferTimeRange = loadedTimeRanges?.first?.timeRangeValue {
                let star = bufferTimeRange.start.seconds         // The start time of the time range.
                let duration = bufferTimeRange.duration.seconds  // The duration of the time range.
                let bufferTime = star + duration
                if let itemDuration = playerItem?.duration.seconds {
                    slider.setProgress(Float(bufferTime/itemDuration), animated: true)
                    if itemDuration == bufferTime {
                        bufferState = .bufferFinished
                    }
                    
                }
                if playerItem.duration.seconds == bufferTime {
                    
                    bufferState = .bufferFinished
                    
                } else{
                    if let currentTime = playerItem?.currentTime().seconds{
                        if (bufferTime - currentTime) >= bufferInterval {
                            if player.rate == 1{
                                self.player.play()
                            }
                        }
                        
                        if (bufferTime - currentTime) < bufferInterval {
                            bufferState = .buffering
                    
                        } else {
                        
                            bufferState = .readyToPlay
                            self.secondToResume = nil
                        }
                    }
                }

            } else {
                if player.rate == 1{
                    self.player.play()
                }

            }
        } else if keyPath == "rate"{
            if player.rate == 1{
                self.startPlaying = true
            }
        }
    }
    
    @objc func playerDidFinishPlaying() {
        if !self.isScrolling{
            self.playButton.isSelected = true
            self.playButton.setImage(imageConfig.replayImg, for: .selected)
            if self.nextButton.isUserInteractionEnabled && isAutoPlay{
                nextAction(nextButton)
            }
        }
        self.delegate?.didFinishPlaying()
    }
    
    private func updateTimeLabel(){
        let current = player.currentItem?.currentTime().seconds ?? 0
        let total = playerAsset.duration.seconds
        if total != current && !playButton.isHidden{
            if playButton.isSelected{
                
                playButton.setImage(imageConfig.playImg, for: .selected)
            } else{
                playButton.setImage(imageConfig.pauseImg, for: .normal)
            }
        }
        timeLabel.text = "\(current.asString(style: .positional)) / \(total.asString(style: .positional))"
    }
    private func updateSliderBar(){
        guard isScrolling == false else {return}
        let current = player.currentItem?.currentTime().seconds ?? 0
        let total = playerAsset.duration.seconds
        let d = Float(current)/Float(total)
        slider.value = d
    
    }
    private func showloading(){
        loadingView.startAnimating()
        playButton.isHidden = true
        loadingView.isHidden = false
    }
    private func hideloading(){
        loadingView.stopAnimating()
        if !isScrolling{
            playButton.isHidden = false
        }
        loadingView.isHidden = true
    }
    private func playViewBufferStateChanged(_ state: RaPlayerBufferstate){
        if state == .buffering{
            showloading()
        } else{
            hideloading()
        }
    }
    func removeObserve() {
        if let item = self.playerItem {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item)
        }
    }
    func isNextAvailable() -> Bool{
        guard let item = self.selectedVideo else {return false}
        guard videoList.count > 1 else {return false}
        return item.title != videoList.last?.title
    }
    func isPreviousAvailable() -> Bool {
        guard let item = self.selectedVideo else {return false}
        guard videoList.count > 1 else {return false}
        return item.title != videoList.first?.title
    }
    private func checkNextPrevious(){
        self.enableButton(previousButton, enable: self.isPreviousAvailable())
        self.enableButton(nextButton, enable: self.isNextAvailable())
    }
}

//MARK: - Set View Layout
extension RaVideoPlayerView{
    /// Initialize Button
    private func setButton(_ button: UIButton, bg_color: UIColor = .clear, normalImage: UIImage? = nil, selectedImage: UIImage? = nil, action: Selector, inset: CGFloat = 0){
        button.translatesAutoresizingMaskIntoConstraints = false
        //button.backgroundColor = bg_color
        button.addTarget(self, action: action, for: .touchUpInside)
        button.isSelected = false
        button.setImage(normalImage, for: .normal)
        button.setImage(selectedImage, for: .selected)
        button.imageEdgeInsets = .init(top: inset, left: inset, bottom: inset, right: inset)
    }
    
    private func enableButton(_ button: UIButton, enable: Bool){
        button.isUserInteractionEnabled = enable
        button.alpha = enable ? 1:0.5
    }
    /// Setup View Layout
    private func setViewLayout(){
        playerView = .init(frame: .zero)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.backgroundColor = .black
        addSubview(playerView)
        bgView = UIView.init(frame: .zero)
        bgView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        bgView.translatesAutoresizingMaskIntoConstraints = false
        ///Double Tap Gesture
        let doubleTap = UITapGestureRecognizer.init(target: self, action: #selector(doubleTapPlayer(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delaysTouchesBegan = true
        
        playerView.addGestureRecognizer(doubleTap)

        //self.addGestureRecognizer(doubleTap)
        
        addSubview(bgView)
        setupButton()
    }
    
    /// Set Cover Background Hidden
    private func setCoverHidden(_ hide: Bool){
        bgView.isHidden = hide
    }
    
    /// Set seeking animation view
    private func setSeekingAnimationView(){
        seekingForwardView = .init(direction: .right)
        seekingForwardView.translatesAutoresizingMaskIntoConstraints = false
        
        playerView.addSubview(seekingForwardView)
        
        NSLayoutConstraint.activate([
            seekingForwardView.leadingAnchor.constraint(equalTo: playerView.centerXAnchor),
            seekingForwardView.topAnchor.constraint(equalTo: playerView.topAnchor),
            seekingForwardView.bottomAnchor.constraint(equalTo: playerView.bottomAnchor),
            seekingForwardView.trailingAnchor.constraint(equalTo: playerView.trailingAnchor)
        ])
        
        seekingBackwardView = .init(direction: .left)
        seekingBackwardView.translatesAutoresizingMaskIntoConstraints = false
        seekingBackwardView.transform = CGAffineTransform(scaleX: -1, y: 1)
        seekingBackwardView.descriptionLabel.transform = CGAffineTransform(scaleX: -1, y: 1)
        playerView.addSubview(seekingBackwardView)
        
        NSLayoutConstraint.activate([
            seekingBackwardView.trailingAnchor.constraint(equalTo: playerView.centerXAnchor),
            seekingBackwardView.topAnchor.constraint(equalTo: playerView.topAnchor),
            seekingBackwardView.heightAnchor.constraint(equalTo: playerView.heightAnchor),
            seekingBackwardView.leadingAnchor.constraint(equalTo: playerView.leadingAnchor)
        ])
    }
    
    /// Setup Button Layout
    private func setupButton(){
        loadingView = .init(frame: .zero)
        if #available(iOS 13.0, *) {
            loadingView.style = .medium
        } else {
            // Fallback on earlier versions
        }
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.isHidden = true
        loadingView.tintColor = .white
        loadingView.color = .white

        playerView.addSubview(loadingView)
        
        ///Button
        playButton = UIButton.init(frame: .zero)
        previousButton = UIButton.init(frame: .zero)
        nextButton = UIButton.init(frame: .zero)
        rewindButton = UIButton.init(frame: .zero)
        forwardButton = UIButton.init(frame: .zero)
        
        optionButton = UIButton.init(frame: .zero)
        picInPicButton = UIButton.init(frame: .zero)
        fullScreenButton = UIButton.init(frame: .zero)
        
        setButton(playButton, bg_color: .white, normalImage: imageConfig.pauseImg,selectedImage: .init(named: "play"), action: #selector(playAction(_:)))
        setButton(previousButton, bg_color: .white, normalImage: imageConfig.previousImg, action: #selector(previousAction(_:)))
        setButton(nextButton, bg_color: .white, normalImage: imageConfig.nextImg, action: #selector(nextAction(_:)))
        setButton(rewindButton, bg_color: .white, normalImage: imageConfig.rewindImg, action: #selector(rewindAction(_:)))
        setButton(forwardButton, bg_color: .white, normalImage: imageConfig.forwardImage, action: #selector(forwardAction(_:)))
        
        setButton(optionButton, bg_color: .white, normalImage: imageConfig.optionImg, action: #selector(optionAction(_:)))
        setButton(picInPicButton, bg_color: .white, normalImage: imageConfig.airplayImg, action: #selector(airPlayAction(_:)))
        setButton(fullScreenButton, bg_color: .white, normalImage: imageConfig.fullScreenImg, selectedImage: imageConfig.exitFullScreenImg, action: #selector(fullscreenAction(_:)), inset: 5)
        
        bgView.addSubview(playButton)
        bgView.addSubview(previousButton)
        bgView.addSubview(nextButton)
        bgView.addSubview(rewindButton)
        bgView.addSubview(forwardButton)
        
        bgView.addSubview(optionButton)
        bgView.addSubview(picInPicButton)
        bgView.addSubview(fullScreenButton)
        
        ///Label
        timeLabel = UILabel.init(frame: .zero)
        timeLabel.textAlignment = .left
        timeLabel.text = "00:00 / 00:00"
        timeLabel.textColor = .white
        timeLabel.font = UIFont.systemFont(ofSize: 12)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        bgView.addSubview(timeLabel)
        
        ///Slider
        slider = .init(thumbImage:imageConfig.thumbImg)
        slider.delegate = self
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderEndSrubbing), for: .touchUpInside)
        bgView.addSubview(slider)
        
        ///Slider Thumbnail
        sliderThumbnail = .init(frame: .zero)
        sliderThumbnail.translatesAutoresizingMaskIntoConstraints = false
        sliderThumbnail.isHidden = true
        bgView.addSubview(sliderThumbnail)
        
        superViewConstraint = [
            playerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            playerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            playerView.widthAnchor.constraint(equalTo: widthAnchor),
            playerView.heightAnchor.constraint(equalTo: heightAnchor),
            
            bgView.centerXAnchor.constraint(equalTo: centerXAnchor),
            bgView.centerYAnchor.constraint(equalTo: centerYAnchor),
            bgView.widthAnchor.constraint(equalTo: widthAnchor),
            bgView.heightAnchor.constraint(equalTo: heightAnchor),
        ]
        topButtonConstraint = [
            optionButton.heightAnchor.constraint(equalToConstant: smallButtonSize/2),
            optionButton.widthAnchor.constraint(equalTo: optionButton.heightAnchor),
            optionButton.topAnchor.constraint(equalTo: topAnchor, constant: smallSpace),
            optionButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -smallSpace),
            
            fullScreenButton.heightAnchor.constraint(equalToConstant: smallButtonSize),
            fullScreenButton.widthAnchor.constraint(equalTo: fullScreenButton.heightAnchor),
            fullScreenButton.bottomAnchor.constraint(equalTo: playerView.bottomAnchor, constant: -smallSpace),
            fullScreenButton.trailingAnchor.constraint(equalTo: playerView.trailingAnchor, constant: -mediumSpace),
        ]
        /// Constraint Setup
        NSLayoutConstraint.activate(superViewConstraint)
        NSLayoutConstraint.activate(topButtonConstraint)
        NSLayoutConstraint.activate([
            playButton.heightAnchor.constraint(equalToConstant: smallButtonSize),
            playButton.widthAnchor.constraint(equalTo: playButton.heightAnchor),
            playButton.centerXAnchor.constraint(equalTo: playerView.centerXAnchor),
            playButton.centerYAnchor.constraint(equalTo: playerView.centerYAnchor),
            
            forwardButton.heightAnchor.constraint(equalToConstant: smallButtonSize),
            forwardButton.widthAnchor.constraint(equalTo: forwardButton.heightAnchor),
            forwardButton.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: buttonSpace),
            forwardButton.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            
            rewindButton.heightAnchor.constraint(equalToConstant: smallButtonSize),
            rewindButton.widthAnchor.constraint(equalTo: rewindButton.heightAnchor),
            rewindButton.trailingAnchor.constraint(equalTo: playButton.leadingAnchor, constant: -buttonSpace),
            rewindButton.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            
            nextButton.heightAnchor.constraint(equalToConstant: smallButtonSize/2),
            nextButton.widthAnchor.constraint(equalTo: nextButton.heightAnchor),
            nextButton.leadingAnchor.constraint(equalTo: forwardButton.trailingAnchor, constant: buttonSpace),
            nextButton.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            
            previousButton.heightAnchor.constraint(equalToConstant: smallButtonSize/2),
            previousButton.widthAnchor.constraint(equalTo: previousButton.heightAnchor),
            previousButton.trailingAnchor.constraint(equalTo: rewindButton.leadingAnchor, constant: -buttonSpace),
            previousButton.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            
            picInPicButton.heightAnchor.constraint(equalToConstant: smallButtonSize/2),
            picInPicButton.widthAnchor.constraint(equalTo: picInPicButton.heightAnchor),
            picInPicButton.topAnchor.constraint(equalTo: topAnchor, constant: smallSpace),
            picInPicButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: smallSpace),

            
            timeLabel.leadingAnchor.constraint(equalTo: playerView.leadingAnchor, constant: mediumSpace),
            timeLabel.centerYAnchor.constraint(equalTo: fullScreenButton.centerYAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: fullScreenButton.leadingAnchor),
            
            slider.leadingAnchor.constraint(equalTo: timeLabel.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -mediumSpace),
            slider.bottomAnchor.constraint(equalTo: fullScreenButton.topAnchor, constant: -8),
            slider.heightAnchor.constraint(equalToConstant: 10),
            
            sliderThumbnail.bottomAnchor.constraint(equalTo: slider.topAnchor, constant: -4),
            sliderThumbnail.widthAnchor.constraint(equalToConstant: sliderThumbnailWidth),
            sliderThumbnail.heightAnchor.constraint(equalToConstant: sliderThumbnailWidth),
            sliderThumbnail.leadingAnchor.constraint(equalTo: slider.leadingAnchor),
            
            loadingView.centerXAnchor.constraint(equalTo: playerView.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: playerView.centerYAnchor)
        ])
    }
}

//MARK: - Action Control
extension RaVideoPlayerView{
    //Play Pause
    @objc func playAction(_ sender: UIButton){
        guard self.player.currentTime().seconds != self.player.currentItem?.duration.seconds else {
            self.player.seek(to: CMTime.zero)
            self.player.play()
            return
        }
        DispatchQueue.main.async {
            sender.isSelected = !sender.isSelected
            let img = !sender.isSelected ? self.imageConfig.pauseImg:self.imageConfig.playImg
            self.playButton.setImage(img, for: .normal)
            if !sender.isSelected{
                self.player.play()
            } else{
                self.player.pause()
            }
        }
    }
    //Next
    @objc func nextAction(_ sender: UIButton){
        sender.isSelected = !sender.isSelected
        guard let video = self.selectedVideo else {return}
        guard let order = videoList.firstIndex(where: {$0.title == video.title}) else {return}
        self.selectedVideo = videoList[order + 1]
        self.checkNextPrevious()
        self.setPlayer()
    }
    //Previous
    @objc func previousAction(_ sender: UIButton){
        sender.isSelected = !sender.isSelected
        guard let video = self.selectedVideo else {return}
        guard let order = videoList.firstIndex(where: {$0.title == video.title}) else {return}
        self.selectedVideo = videoList[order - 1]
        self.setPlayer()
    }
    //Forward
    @objc func forwardAction(_ sender: UIButton){
        sender.isSelected = !sender.isSelected
        seekingAnimation(.right)
    }
    //Rewind
    @objc func rewindAction(_ sender: UIButton){
        sender.isSelected = !sender.isSelected
        seekingAnimation(.left)
    }
    //Fullscreen
    @objc func fullscreenAction(_ sender: UIButton){
        sender.isSelected = !sender.isSelected
        isFullScreen = sender.isSelected
        if isFullScreen{
            enterFullScreen()
        } else {
            exitFullScreen()
        }
    }
    //Option
    @objc func optionAction(_ sender: UIButton){
        sender.isSelected = !sender.isSelected
        delegate?.didTapOnOption()
    }
    @objc func airPlayAction(_ sender: UIButton){
        if #available(iOS 11.0, *) {
            routePickerView.present()
        } else {
            // Fallback on earlier versions
        }
    }
}
fileprivate extension AVRoutePickerView {
    func present() {
        let routePickerButton = subviews.first(where: { $0 is UIButton }) as? UIButton
        routePickerButton?.sendActions(for: .touchUpInside)
    }
}

extension RaVideoPlayerView{
    internal func addDeviceOrientationNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(deviceOrientationWillChange(_:)), name: UIApplication.willChangeStatusBarOrientationNotification, object: nil)
    }
    public func enterFullScreen(){
        let statusBarOrientation = UIApplication.shared.statusBarOrientation
        if statusBarOrientation == .portrait{
            if let v = self.superview?.frame{
                self.viewFrame = v
            }
            
            self.layoutIfNeeded()
        }
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        UIApplication.shared.statusBarOrientation = .landscapeRight
        UIApplication.shared.setStatusBarHidden(false, with: .fade)
    }
    public func exitFullScreen(){
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        UIApplication.shared.statusBarOrientation = .portrait
    }
    
    public func onDeviceOrientation(_ isFullScreen: Bool, orientation: UIInterfaceOrientation){
        self.isFullScreen = isFullScreen
        let statusBarOrientation = UIApplication.shared.statusBarOrientation
        if orientation == statusBarOrientation {
 
        } else{
            if orientation == .landscapeLeft || orientation == .landscapeRight {
                self.baseConstraint = [
                    
                    self.centerXAnchor.constraint(equalTo: superview!.centerXAnchor),
                    self.topAnchor.constraint(equalTo: superview!.topAnchor, constant: 0),
                    self.widthAnchor.constraint(equalTo: superview!.widthAnchor),
                    self.heightAnchor.constraint(equalTo: superview!.heightAnchor),
                ]
                NSLayoutConstraint.deactivate(superViewConstraint)
                NSLayoutConstraint.deactivate(topButtonConstraint)
                NSLayoutConstraint.deactivate(baseConstraint)

                
                superViewConstraint = [
                    playerView.centerXAnchor.constraint(equalTo: superview!.centerXAnchor),
                    playerView.topAnchor.constraint(equalTo: superview!.topAnchor),
                    playerView.widthAnchor.constraint(equalTo: superview!.widthAnchor),
                    playerView.heightAnchor.constraint(equalTo: superview!.heightAnchor),
                    
                    bgView.centerXAnchor.constraint(equalTo: superview!.centerXAnchor),
                    bgView.topAnchor.constraint(equalTo: superview!.topAnchor),
                    bgView.widthAnchor.constraint(equalTo: superview!.widthAnchor),
                    bgView.heightAnchor.constraint(equalTo: superview!.heightAnchor),
                ]
                let topPadding : CGFloat = UIDevice.current.hasNotch ? self.mediumSpace:self.smallSpace
                topButtonConstraint = [
                    picInPicButton.heightAnchor.constraint(equalToConstant: smallButtonSize/2),
                    picInPicButton.widthAnchor.constraint(equalTo: picInPicButton.heightAnchor),
                    picInPicButton.topAnchor.constraint(equalTo: superview!.topAnchor, constant: topPadding),
                    picInPicButton.leadingAnchor.constraint(equalTo: superview!.leadingAnchor, constant: mediumSpace),
                    
                    optionButton.heightAnchor.constraint(equalToConstant: smallButtonSize/2),
                    optionButton.widthAnchor.constraint(equalTo: optionButton.heightAnchor),
                    optionButton.topAnchor.constraint(equalTo: superview!.topAnchor, constant: smallSpace),
                    optionButton.trailingAnchor.constraint(equalTo: superview!.trailingAnchor, constant: -topPadding),
                    
                    fullScreenButton.heightAnchor.constraint(equalToConstant: smallButtonSize),
                    fullScreenButton.widthAnchor.constraint(equalTo: fullScreenButton.heightAnchor),
                    fullScreenButton.bottomAnchor.constraint(equalTo: playerView.bottomAnchor, constant: -smallSpace),
                    fullScreenButton.trailingAnchor.constraint(equalTo: playerView.trailingAnchor, constant: -mediumSpace),
                ]
                NSLayoutConstraint.activate(baseConstraint)
                NSLayoutConstraint.activate(superViewConstraint)
                NSLayoutConstraint.activate(topButtonConstraint)
                
            } else if orientation == .portrait{
                if parentView == nil {
                    return }
                _ = parentView?.convert(viewFrame, to: UIApplication.shared.keyWindow)
                NSLayoutConstraint.deactivate(superViewConstraint)
                NSLayoutConstraint.deactivate(topButtonConstraint)
                NSLayoutConstraint.deactivate(baseConstraint)
                baseConstraint = [
                    self.leadingAnchor.constraint(equalTo: leadingAnchor),
                    self.topAnchor.constraint(equalTo: topAnchor),
                    self.widthAnchor.constraint(equalToConstant: viewFrame.width),
                    self.heightAnchor.constraint(equalToConstant: viewFrame.height),
                ]
                superViewConstraint = [
                    playerView.leadingAnchor.constraint(equalTo: leadingAnchor),
                    playerView.topAnchor.constraint(equalTo: topAnchor),
                    playerView.widthAnchor.constraint(equalToConstant: viewFrame.width),
                    playerView.heightAnchor.constraint(equalToConstant: viewFrame.height),

                    bgView.leadingAnchor.constraint(equalTo: leadingAnchor),
                    bgView.topAnchor.constraint(equalTo: topAnchor),
                    bgView.widthAnchor.constraint(equalToConstant: viewFrame.width),
                    bgView.heightAnchor.constraint(equalToConstant: viewFrame.height),
                ]
                
                topButtonConstraint = [
                    picInPicButton.heightAnchor.constraint(equalToConstant: smallButtonSize/2),
                    picInPicButton.widthAnchor.constraint(equalTo: picInPicButton.heightAnchor),
                    picInPicButton.topAnchor.constraint(equalTo: topAnchor, constant: mediumSpace),
                    picInPicButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: mediumSpace),
                    
                    optionButton.heightAnchor.constraint(equalToConstant: smallButtonSize/2),
                    optionButton.widthAnchor.constraint(equalTo: optionButton.heightAnchor),
                    optionButton.topAnchor.constraint(equalTo: topAnchor, constant: mediumSpace),
                    optionButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -mediumSpace),
                    
                    fullScreenButton.heightAnchor.constraint(equalToConstant: smallButtonSize),
                    fullScreenButton.widthAnchor.constraint(equalTo: fullScreenButton.heightAnchor),
                    fullScreenButton.bottomAnchor.constraint(equalTo: playerView.bottomAnchor, constant: -smallSpace),
                    fullScreenButton.trailingAnchor.constraint(equalTo: playerView.trailingAnchor, constant: -mediumSpace),
                ]
                NSLayoutConstraint.activate(baseConstraint)
                NSLayoutConstraint.activate(superViewConstraint)
                NSLayoutConstraint.activate(topButtonConstraint)
                parentView = nil
                viewFrame = CGRect()
            }
        }
    }
    @objc internal func deviceOrientationWillChange(_ sender: Notification) {
        let orientation = UIDevice.current.orientation
        let statusBarOrientation = UIApplication.shared.statusBarOrientation
        if statusBarOrientation == .portrait{
            if superview != nil {
                parentView = (superview)!
                viewFrame = frame
            }
        }
        switch orientation {
        case .unknown:
            break
        case .faceDown:
            break
        case .faceUp:
            break
        case .landscapeLeft:
            onDeviceOrientation(true, orientation: .landscapeLeft)
        case .landscapeRight:
            onDeviceOrientation(true, orientation: .landscapeRight)
        case .portrait:
            onDeviceOrientation(false, orientation: .portrait)
        case .portraitUpsideDown:
            onDeviceOrientation(false, orientation: .portraitUpsideDown)
        default:
            break
        }
        self.layoutIfNeeded()
        self.setNeedsLayout()
    }
}

//MARK: - Gesture Regconizer
extension RaVideoPlayerView{
    @objc private func didTapOnPlayer(){
        showHideControl(self.bgView.alpha == 0)
    }
    private func showHideControl(_ show: Bool){
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: {
            self.bgView.alpha = show ? 1:0
        }, completion: nil)
    }
    @objc internal func doubleTapPlayer(_ sender: UITapGestureRecognizer){
        let point = sender.location(in: self)
        let left = point.x < center.x
        let direction : SeekingDirection = left ? .left:.right
        seekingAnimation(direction)
    }
    
    internal func seekingAnimation(_ direction: SeekingDirection, times: CGFloat? = nil){
        let time = direction == .left ? -(times ?? tapSeekSeconds) : (times ?? tapSeekSeconds)
        let toSeek = (player.currentItem?.currentTime().seconds ?? 0) + time
        guard toSeek <= playerItem.duration.seconds, toSeek >= 0 else {return}
        player.seek(to: .init(seconds: toSeek, preferredTimescale: 1))
        if direction == .left{
            bringSubview(toFront: seekingBackwardView)
            seekingBackwardView.setAnimation()
        } else{
            bringSubview(toFront: seekingForwardView)
            seekingForwardView.setAnimation()
        }
    }
}

//MARK: - Slider Control
extension RaVideoPlayerView{
    @objc private func sliderEndSrubbing(){
        /// Hide Thumbnail
        self.isScrolling = false
        showHideControlExcept([sliderThumbnail], show: true)
        
        ///Seek player
        let current = Double(slider.value) * playerItem.duration.seconds
        let time = CMTime.init(seconds: current, preferredTimescale: 1)
        player.seek(to: time)
    }
    @objc private func sliderValueChanged(_ sender: UISlider){
        /// Todo: Hide Control
        self.isScrolling = true
        showHideControlExcept([slider, sliderThumbnail], show: false)
        
        /// Move Thumbnail Slider
        let _thumbRect: CGRect = sender.thumbRect(forBounds: sender.bounds, trackRect: sender.trackRect(forBounds: sender.bounds), value: sender.value)

        let thumbRect: CGRect = convert(_thumbRect, from: sender)
        moveSliderThumb(thumbRect)
        
        /// Set Thumnail Slider Data
        let current = Double(sender.value) * playerItem.duration.seconds
        let time = CMTime.init(seconds: current, preferredTimescale: 1)
        setSliderThumb(time: time)
    }
    private func showHideControlExcept(_ exceptions: [UIView], show: Bool){
        for view in bgView.subviews{
            if !exceptions.contains(view){
                view.isHidden = !show
            } else{
                view.isHidden = show
            }
        }
    }
    private func moveSliderThumb(_ rect: CGRect){
        guard rect.midX >= sliderThumbnailWidth/2 + 30, rect.midX <= bgView.frame.width - sliderThumbnailWidth/2 - 30 else {return}
        sliderThumbnail.center.x = rect.midX
    }
    private func setSliderThumb(time: CMTime){
        let text = time.seconds.asString(style: .positional)
        self.sliderThumbnail.setThumbText(text: text)
        DispatchQueue.global(qos: .background).async {
            self.videoSnapshot(current: time){ img in
                if let img = img{
                    DispatchQueue.main.async {
                        if self.startPlaying && text == self.sliderThumbnail.timeLabel.text{
                                self.sliderThumbnail.setThumbImage(image: img)
                        }
                    }
                }
            }
        }
    }
    
    func videoSnapshot(current: CMTime, completion: @escaping (UIImage?) -> Void){
        
        let generator = AVAssetImageGenerator(asset: playerItem.asset)
        generator.appliesPreferredTrackTransform = true
        generator.apertureMode = .cleanAperture

        let timestamp = current
        let times = [NSValue(time: timestamp)]
        generator.generateCGImagesAsynchronously(forTimes: times){requestedTime, image, actualTime, result, error in
            guard let image = image else {return}
            let img = UIImage(cgImage: image)
            completion(img)
        }
    }
    func createPulse(_ center: CGPoint) {
           for _ in 0...2 {
               let circularPath = UIBezierPath(arcCenter: .zero, radius: UIScreen.main.bounds.size.width/2.0, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
               let pulseLayer = CAShapeLayer()
               pulseLayer.path = circularPath.cgPath
               pulseLayer.lineWidth = 2.0
               pulseLayer.fillColor = UIColor.lightText.cgColor
               if #available(iOS 13.0, *) {
                   pulseLayer.lineCap = CAShapeLayerLineCap.round
               }
               pulseLayer.position = center
               seekingForwardView.layer.addSublayer(pulseLayer)
               pulseArray.append(pulseLayer)
           }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
              self.animatePulsatingLayerAt(index: 0)
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: {
                  self.animatePulsatingLayerAt(index: 1)
                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                      self.animatePulsatingLayerAt(index: 2)
                  })
              })
          })
     }
    func animatePulsatingLayerAt(index:Int) {
         
         //Giving color to the layer
         pulseArray[index].strokeColor = UIColor.darkGray.cgColor
         
         //Creating scale animation for the layer, from and to value should be in range of 0.0 to 1.0
         // 0.0 = minimum
         //1.0 = maximum
         let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
         scaleAnimation.fromValue = 0.0
         scaleAnimation.toValue = 0.9
         
         //Creating opacity animation for the layer, from and to value should be in range of 0.0 to 1.0
         // 0.0 = minimum
         //1.0 = maximum
         let opacityAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
         opacityAnimation.fromValue = 0.9
         opacityAnimation.toValue = 0.0
        
        //Grouping both animations and giving animation duration, animation repat count
         let groupAnimation = CAAnimationGroup()
         groupAnimation.animations = [scaleAnimation, opacityAnimation]
         groupAnimation.duration = 2.3
         groupAnimation.repeatCount = .greatestFiniteMagnitude
         groupAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
         //adding groupanimation to the layer
         pulseArray[index].add(groupAnimation, forKey: "groupanimation")
         
     }
}
extension AVPlayer {
    func generateThumbnail(time: CMTime) -> UIImage? {
        guard let asset = currentItem?.asset else { return nil }
        let imageGenerator = AVAssetImageGenerator(asset: asset)

        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print(error.localizedDescription)
        }

        return nil
    }
}
extension RaVideoPlayerView: PanGestureDelegate{
    func moveEnd(x: CGFloat) {
        sliderEndSrubbing()
    }
    func moveStart(x: CGFloat) {
        sliderValueChanged(slider)
    }
}
extension Double {
  func asString(style: DateComponentsFormatter.UnitsStyle) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second, .nanosecond]
    formatter.unitsStyle = style
    return formatter.string(from: self) ?? ""
  }
}
extension UIDevice {
    var hasNotch: Bool {
        if #available(iOS 11.0, *) {
            let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
            return keyWindow?.safeAreaInsets.bottom ?? 0 > 0
        }
        return false
    }

}


