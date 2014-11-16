//
//  UDContactImageView.swift
//  udo
//
//  Created by Osman Alpay on 12/11/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation

class UDContactImageView:PFImageView {
    private var imageLoadingActivityIndicator:UIActivityIndicatorView!
    
    
    override func awakeFromNib() {
        self.imageLoadingActivityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
        self.imageLoadingActivityIndicator.frame = CGRect(x:  self.frame.width/2 - 15, y: self.frame.height/2 - 15, width: 30, height: 30)
        self.addSubview(self.imageLoadingActivityIndicator)
    }

    func loadWithContact(contact:UDContact,showIndicator:Bool){
        self.image = contact.contactImage()
        if let imageFile = contact.publicImageFile() {
            if let cachedImage = contact.cachedPublicImage() {
               self.image = cachedImage
            }else {
                self.file = imageFile
                if showIndicator {
                    self.imageLoadingActivityIndicator.startAnimating()
                }
                self.loadInBackground({ (image:UIImage!, error:NSError!) -> Void in
                    if error == nil {
                        contact.cachePublicImage(image)
                    }
                    if showIndicator{
                        self.imageLoadingActivityIndicator.stopAnimating()
                    }
                })
                
            }
        }
    }
}
