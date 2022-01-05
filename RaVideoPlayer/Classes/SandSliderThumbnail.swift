//
//  RaSliderThumbnail.swift
//  RaVideoPlayer
//
//  Created by Ouch Kemvanra on 12/30/21.
//

import Foundation
import UIKit
class RaSliderThumbnail: UIView{
    
    var thumbnail: UIImageView!
    var timeLabel: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView(){

        thumbnail = UIImageView.init(frame: .zero)
        thumbnail.translatesAutoresizingMaskIntoConstraints = false
        thumbnail.contentMode = .scaleAspectFill
        thumbnail.backgroundColor = .clear
        
        timeLabel = UILabel.init(frame: .zero)
        timeLabel.textAlignment = .center
        timeLabel.text = "00:00"
        timeLabel.textColor = .white
        timeLabel.font = UIFont.systemFont(ofSize: 12)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(thumbnail)
        addSubview(timeLabel)
        
        NSLayoutConstraint.activate([
            thumbnail.leadingAnchor.constraint(equalTo: leadingAnchor),
            thumbnail.topAnchor.constraint(equalTo: topAnchor),
            thumbnail.trailingAnchor.constraint(equalTo: trailingAnchor),
            thumbnail.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            
            timeLabel.topAnchor.constraint(equalTo: thumbnail.bottomAnchor),
            timeLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            timeLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        
        ])
    }
    public func setThumbImage(image: UIImage){
        self.thumbnail.image = image

    }
    public func setThumbText(text: String){
        self.timeLabel.text = text
    }
}

