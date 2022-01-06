//
//  RaSeekingView.swift
//  RaVideoPlayer
//
//  Created by Ouch Kemvanra on 12/30/21.
//

import Foundation
import UIKit
class RaSeekingView : UIView{
    let triangleOne: TriangleView = {
        let v = TriangleView.init(frame: .zero)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.alpha = 0
        return v
    }()
    let triangleTwo: TriangleView = {
        let v = TriangleView.init(frame: .zero)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.alpha = 0
        return v
    }()
    let triangleThree: TriangleView = {
        let v = TriangleView.init(frame: .zero)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.alpha = 0
        return v
    }()
    let descriptionLabel: UILabel = {
        let lb = UILabel.init(frame: .zero)
        lb.translatesAutoresizingMaskIntoConstraints = false
        lb.text = "+15 seconds"
        lb.font = lb.font.withSize(10)
        lb.textColor = .black
        lb.textAlignment = .left
        lb.alpha = 0
        return lb
    }()
    override init(frame: CGRect) {
        super.init(frame: frame)
        setViewLayout()
    }
    init(direction: SeekingDirection){
        super.init(frame: .zero)
        descriptionLabel.text = direction == .left ? "-15 seconds":"+15 seconds"
        setViewLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    internal func setViewLayout(){
        addSubview(triangleTwo)
        addSubview(triangleOne)
        addSubview(triangleThree)
        addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            triangleTwo.widthAnchor.constraint(equalToConstant: 20),
            triangleTwo.heightAnchor.constraint(equalToConstant: 20),
            triangleTwo.centerXAnchor.constraint(equalTo: centerXAnchor),
            triangleTwo.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            triangleOne.widthAnchor.constraint(equalToConstant: 20),
            triangleOne.heightAnchor.constraint(equalToConstant: 20),
            triangleOne.trailingAnchor.constraint(equalTo: triangleTwo.leadingAnchor, constant: 4),
            triangleOne.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            triangleThree.widthAnchor.constraint(equalToConstant: 20),
            triangleThree.heightAnchor.constraint(equalToConstant: 20),
            triangleThree.leadingAnchor.constraint(equalTo: triangleTwo.trailingAnchor, constant: -4),
            triangleThree.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            descriptionLabel.leadingAnchor.constraint(equalTo: triangleOne.leadingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: triangleOne.bottomAnchor)
        ])
    }
    
    public func setAnimation(){
        DispatchQueue.main.asyncAfter(deadline: .now()){
            self.descriptionLabel.fadeIn(duration: 0.1)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25){
            self.descriptionLabel.fadeOut(duration: 0.2)
        }
        DispatchQueue.main.asyncAfter(deadline: .now()){
            self.triangleOne.fadeIn(duration: 0.1)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1){
            self.triangleOne.fadeOut(duration: 0.2)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15){
            self.triangleTwo.fadeIn(duration: 0.1)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2){
            self.triangleTwo.fadeOut(duration: 0.2)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25){
            self.triangleThree.fadeIn(duration: 0.1)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3){
            self.triangleThree.fadeOut(duration: 0.2)
        }
    }
}
class TriangleView : UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func draw(_ rect: CGRect) {
       let widthHeight = self.layer.frame.size.height

       let triangle = CAShapeLayer()
       triangle.fillColor = UIColor.black.cgColor
       triangle.path = roundedTriangle(widthHeight: widthHeight)
       triangle.position = CGPoint(x: 0, y: 0)
       self.layer.addSublayer(triangle)
       let angleInRadians = 90 / 180.0 * CGFloat.pi
       let rotation = self.transform.rotated(by: angleInRadians)
       self.transform = rotation
    }

    func roundedTriangle(widthHeight: CGFloat) -> CGPath {
       let point1 = CGPoint(x: widthHeight/2, y:0)
       let point2 = CGPoint(x: widthHeight , y: widthHeight)
       let point3 =  CGPoint(x: 0, y: widthHeight)
  
       let path = CGMutablePath()

       path.move(to: CGPoint(x: 0, y: widthHeight))
       path.addArc(tangent1End: point1, tangent2End: point2, radius: 2)
       path.addArc(tangent1End: point2, tangent2End: point3, radius: 2)
       path.addArc(tangent1End: point3, tangent2End: point1, radius: 2)
       path.closeSubpath()
       return path
    }
}


