//
//  INSPhotoViewController.swift
//  INSPhotoViewer
//
//  Created by Michal Zaborowski on 28.02.2016.
//  Copyright © 2016 Inspace Labs Sp z o. o. Spółka Komandytowa. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this library except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import UIKit

open class INSPhotoViewController: UIViewController, UIScrollViewDelegate {
    var photo: INSPhotoViewable
    
    var longPressGestureHandler: ((UILongPressGestureRecognizer) -> ())?
    var willBeginZoomingHandler: ((INSPhotoViewController)->())?
    var willBeginDraggingHandler: ((INSPhotoViewController)->())?
    
    lazy private(set) var scalingImageView: INSScalingImageView = {
        let scalingImageView = INSScalingImageView()
        return scalingImageView
    }()
    
    lazy private(set) var doubleTapGestureRecognizer: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(INSPhotoViewController.handleDoubleTapWithGestureRecognizer(_:)))
        gesture.numberOfTapsRequired = 2
        return gesture
    }()
    
    lazy private(set) var longPressGestureRecognizer: UILongPressGestureRecognizer = {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(INSPhotoViewController.handleLongPressWithGestureRecognizer(_:)))
        return gesture
    }()
    
    lazy private(set) var activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .white)
        activityIndicator.startAnimating()
        return activityIndicator
    }()
    
    public init(photo: INSPhotoViewable) {
        self.photo = photo
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        scalingImageView.delegate = nil
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        scalingImageView.delegate = self
        scalingImageView.frame = view.bounds
        scalingImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scalingImageView)
        
        view.addSubview(activityIndicator)
        activityIndicator.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        activityIndicator.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
        activityIndicator.sizeToFit()
        
        view.addGestureRecognizer(doubleTapGestureRecognizer)
        view.addGestureRecognizer(longPressGestureRecognizer)
        
        if let image = photo.image {
            self.scalingImageView.image = image
            self.activityIndicator.stopAnimating()
        } else if let thumbnailImage = photo.thumbnailImage {
            self.scalingImageView.image = thumbnailImage
            self.activityIndicator.stopAnimating()
            loadFullSizeImage()
        } else {
            loadThumbnailImage()
        }

    }
    
    open override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        scalingImageView.frame = view.bounds
    }
    
    private func loadThumbnailImage() {
        view.bringSubview(toFront: activityIndicator)
        photo.loadThumbnailImageWithCompletionHandler { [weak self] (image, error) -> () in
            
            let completeLoading = {
                self?.scalingImageView.image = image
                if image != nil {
                    self?.activityIndicator.stopAnimating()
                }
                self?.loadFullSizeImage()
            }
            
            if Thread.isMainThread {
                completeLoading()
            } else {
                DispatchQueue.main.async(execute: { () -> Void in
                    completeLoading()
                })
            }
        }
    }
    
    private func loadFullSizeImage() {
        view.bringSubview(toFront: activityIndicator)
        self.photo.loadImageWithCompletionHandler({ [weak self] (image, error) -> () in
            let completeLoading = {
                self?.activityIndicator.stopAnimating()
                self?.scalingImageView.image = image    
            }
            
            if Thread.isMainThread {
                completeLoading()
            } else {
                DispatchQueue.main.async(execute: { () -> Void in
                    completeLoading()
                })
            }
        })
    }
    
    @objc private func handleLongPressWithGestureRecognizer(_ recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == UIGestureRecognizerState.began {
            longPressGestureHandler?(recognizer)
        }
    }
    
    @objc private func handleDoubleTapWithGestureRecognizer(_ recognizer: UITapGestureRecognizer) {
        let pointInView = recognizer.location(in: scalingImageView.imageView)
        // default to zoomed in
        let newZoomScale: CGFloat
        let isZoomedIn = abs(scalingImageView.zoomScale - scalingImageView.minimumZoomScale) > 0.01
        if isZoomedIn {
            newZoomScale = scalingImageView.minimumZoomScale
        } else {
            if let image = scalingImageView.image, scalingImageView.contentSize.height <= scalingImageView.bounds.height {
                // zoom to max of full height of screen or 2x height
                let fullHeightZoomScale = scalingImageView.bounds.size.height / image.size.height
                let doubleHeightZoomScale = scalingImageView.minimumZoomScale * 2
                newZoomScale = min(max(fullHeightZoomScale,doubleHeightZoomScale), scalingImageView.maximumZoomScale)
            } else if let image = scalingImageView.image, scalingImageView.contentSize.width <= scalingImageView.bounds.width {
                // zoom to max of full width of screen or 2x width
                let fullWidthZoomScale = scalingImageView.bounds.size.width / image.size.width
                let doubleWidthZoomScale = scalingImageView.minimumZoomScale * 2
                newZoomScale = min(max(fullWidthZoomScale,doubleWidthZoomScale), scalingImageView.maximumZoomScale)
            } else {
                // double the minimum scale zoom
                newZoomScale = min(scalingImageView.minimumZoomScale * 2,scalingImageView.maximumZoomScale)
            }
        }
        
        let scrollViewSize = scalingImageView.bounds.size
        let width = scrollViewSize.width / newZoomScale
        let height = scrollViewSize.height / newZoomScale
        let originX = pointInView.x - (width / 2.0)
        let originY = pointInView.y - (height / 2.0)
        
        let rectToZoom = CGRect(x: originX, y: originY, width: width, height: height)
        scalingImageView.zoom(to: rectToZoom, animated: true)
    }
    
    // MARK:- UIScrollViewDelegate
    
    open func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scalingImageView.imageView
    }
    
    open func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        scrollView.panGestureRecognizer.isEnabled = true
        willBeginZoomingHandler?(self)
    }
    
    open func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        // There is a bug, especially prevalent on iPhone 6 Plus, that causes zooming to render all other gesture recognizers ineffective.
        // This bug is fixed by disabling the pan gesture recognizer of the scroll view when it is not needed.
        if (scrollView.zoomScale == scrollView.minimumZoomScale) {
            scrollView.panGestureRecognizer.isEnabled = false;
        }
    }
    
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        scalingImageView.centerScrollViewContents()
    }
    
    open func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        willBeginDraggingHandler?(self)
    }
}
