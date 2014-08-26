//
//  UDOStackedLayout.swift
//  udo
//
//  Created by Osman Alpay on 22/08/14.
//  Copyright (c) 2014 Osman Alpay. All rights reserved.
//

import Foundation


class UDOStackedLayout: TGLStackedLayout{
    
    override func initLayout() {
        super.initLayout()
    }
    /*
    override func layoutAttributesForSupplementaryViewOfKind(elementKind: String!, atIndexPath indexPath: NSIndexPath!) -> UICollectionViewLayoutAttributes! {
        var layoutAttributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: RemindersHeader.kind(), withIndexPath: indexPath)
        layoutAttributes.frame = CGRect(x: 0.0, y: self.collectionView.contentOffset.y, width: self.self.collectionView.frame.width, height: self.self.collectionView.frame.height)
        layoutAttributes.zIndex = -1
        return layoutAttributes
    }
    
    override func layoutAttributesForElementsInRect(rect: CGRect) -> [AnyObject]! {
        var elements = super.layoutAttributesForElementsInRect(rect)
        var headerAttributes = self.layoutAttributesForSupplementaryViewOfKind(RemindersHeader.kind(), atIndexPath: NSIndexPath(forItem: 0, inSection: 0))
        elements.append(headerAttributes)
        return elements
    }
*/
}