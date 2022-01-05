//
//  RaProgressBar.swift
//  RaVideoPlayer
//
//  Created by Ouch Kemvanra on 10/28/21.
//

import UIKit
protocol PanGestureDelegate: AnyObject{
    func moveStart(x: CGFloat)
    func moveEnd(x: CGFloat)
}
public class RaProgressBar: UISlider{
    open var progressView : UIProgressView
    weak var delegate: PanGestureDelegate?
    private var thumbImage: UIImage?
    
    public override init(frame: CGRect) {
        self.progressView = UIProgressView()
        super.init(frame: frame)
        
    }
    
    convenience init(thumbImage: UIImage) {
        self.init(frame: CGRect.zero)
        self.thumbImage = thumbImage
        configureSlider()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        let rect = super.thumbRect(forBounds: bounds, trackRect: rect, value: value)
        let newRect = CGRect(x: rect.origin.x, y: rect.origin.y + 1, width: rect.width, height: rect.height)
        return newRect
    }
    
    override open func trackRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.trackRect(forBounds: bounds)
        let newRect = CGRect(origin: rect.origin, size: CGSize(width: rect.size.width, height: 4.0))
        configureProgressView(newRect)
        return newRect
    }
    
    func configureSlider() {
        maximumValue = 1.0
        minimumValue = 0.0
        value = 0.0
        maximumTrackTintColor = UIColor.clear
        minimumTrackTintColor = UIColor.white
        
        let normalThumbImage = self.imageSize(image: thumbImage!, scaledToSize: CGSize(width: 15, height: 15))
        setThumbImage(normalThumbImage, for: .normal)
        let highlightedThumbImage = self.imageSize(image: thumbImage!, scaledToSize: CGSize(width: 20, height: 20))
        setThumbImage(highlightedThumbImage, for: .highlighted)
        
        backgroundColor = UIColor.clear
        progressView.tintColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.7988548801)
        progressView.trackTintColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.2964201627)
        
        let panGesture = UIPanGestureRecognizer.init(target: self, action: #selector(panGestureMove(_:)))
        self.addGestureRecognizer(panGesture)
    }
    
    func configureProgressView(_ frame: CGRect) {
        progressView.frame = frame
        insertSubview(progressView, at: 0)
    }
    
    open func setProgress(_ progress: Float, animated: Bool) {
        progressView.setProgress(progress, animated: animated)
    }
    
    func imageSize(image: UIImage, scaledToSize newSize: CGSize) -> UIImage? {
         UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
         image.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
         let newImage = UIGraphicsGetImageFromCurrentImageContext()
         UIGraphicsEndImageContext()
         return newImage
    }
    
    @objc private func panGestureMove(_ gesture: UIPanGestureRecognizer){
        let location = gesture.location(in: self)
        let current = (location.x + 0)/bounds.width
        let c = current < 0 ? 0:(current > 1.0 ? 1:current)
        self.value = Float(c)
        if gesture.state == .ended{
            delegate?.moveEnd(x: location.x)
        } else {
            delegate?.moveStart(x: location.x)
        }
    }
}
