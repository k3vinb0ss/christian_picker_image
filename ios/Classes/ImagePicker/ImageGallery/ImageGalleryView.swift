import UIKit
import Photos

private func < <T: Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (someLhs?, someRhs?):
    return someLhs < someRhs
  case (nil, _?):
    return true
  default:
    return false
  }
}

protocol ImageGalleryPanGestureDelegate: class {

  func panGestureDidStart()
  func panGestureDidChange(_ translation: CGPoint)
  func panGestureDidEnd(_ translation: CGPoint, velocity: CGPoint)
  func itemTapped()
}

open class ImageGalleryView: UIView {

  struct Dimensions {
    static let galleryHeight: CGFloat = 160
    static let galleryBarHeight: CGFloat = 24
  }

  var configurations = Configurations()

  lazy open var collectionView: UICollectionView = { [unowned self] in
    let collectionView = UICollectionView(frame: CGRect.zero,
      collectionViewLayout: self.collectionViewLayout)
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    collectionView.backgroundColor = self.configurations.mainColor
    collectionView.showsHorizontalScrollIndicator = false
    collectionView.dataSource = self
    collectionView.delegate = self

    return collectionView
    }()

  lazy var collectionViewLayout: UICollectionViewLayout = { [unowned self] in
    let layout = ImageGalleryLayout(configurations: self.configurations)
    layout.scrollDirection = .horizontal
    layout.minimumInteritemSpacing = self.configurations.cellSpacing
    layout.minimumLineSpacing = 2
    layout.sectionInset = UIEdgeInsets.zero

    return layout
    }()

  lazy var topSeparator: UIView = { [unowned self] in
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.addGestureRecognizer(self.panGestureRecognizer)
    view.backgroundColor = self.configurations.gallerySeparatorColor

    return view
    }()

  lazy var panGestureRecognizer: UIPanGestureRecognizer = { [unowned self] in
    let gesture = UIPanGestureRecognizer()
    gesture.addTarget(self, action: #selector(handlePanGestureRecognizer(_:)))

    return gesture
    }()

  open lazy var noImagesLabel: UILabel = { [unowned self] in
    let label = UILabel()
    label.font = self.configurations.noImagesFont
    label.textColor = self.configurations.noImagesColor
    label.text = self.configurations.noImagesTitle
    label.alpha = 0
    label.sizeToFit()
    self.addSubview(label)

    return label
    }()

  open lazy var selectedStack = ImageStack()
  lazy var assets = [PHAsset]()

  weak var delegate: ImageGalleryPanGestureDelegate?
  var collectionSize: CGSize?
  var shouldTransform = false
  var imagesBeforeLoading = 0
  var fetchResult: PHFetchResult<AnyObject>?

  // MARK: - Initializers

  public init(configurations: Configurations? = nil) {
    if let configurations = configurations {
      self.configurations = configurations
    }
    super.init(frame: .zero)
    configure()
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    configure()
  }

  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func configure() {
    backgroundColor = configurations.mainColor

    collectionView.register(ImageGalleryViewCell.self,
                            forCellWithReuseIdentifier: CollectionView.reusableIdentifier)

    [collectionView, topSeparator].forEach { addSubview($0) }

    topSeparator.addSubview(configurations.indicatorView)

    imagesBeforeLoading = 0
    fetchPhotos()
  }

  // MARK: - Layout

  open override func layoutSubviews() {
    super.layoutSubviews()
    updateNoImagesLabel()
  }

  func updateFrames() {
    let totalWidth = UIScreen.main.bounds.width
    frame.size.width = totalWidth
    let collectionFrame = frame.height == Dimensions.galleryBarHeight ? 100 + Dimensions.galleryBarHeight : frame.height
    topSeparator.frame = CGRect(x: 0, y: 0, width: totalWidth, height: Dimensions.galleryBarHeight)
    topSeparator.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleWidth]
    configurations.indicatorView.frame = CGRect(x: (totalWidth - configurations.indicatorWidth) / 2, y: (topSeparator.frame.height - configurations.indicatorHeight) / 2,
      width: configurations.indicatorWidth, height: configurations.indicatorHeight)
    collectionView.frame = CGRect(x: 0, y: topSeparator.frame.height, width: totalWidth, height: collectionFrame - topSeparator.frame.height)
    collectionSize = CGSize(width: collectionView.frame.height, height: collectionView.frame.height)
    noImagesLabel.center = CGPoint(x: bounds.width / 2, y: (bounds.height + Dimensions.galleryBarHeight) / 2)

    collectionView.reloadData()
  }

  func updateNoImagesLabel() {
    let height = bounds.height
    let threshold = Dimensions.galleryBarHeight * 2

    UIView.animate(withDuration: 0.25, animations: {
      if threshold > height || self.collectionView.alpha != 0 {
        self.noImagesLabel.alpha = 0
      } else {
        self.noImagesLabel.center = CGPoint(x: self.bounds.width / 2, y: (height + Dimensions.galleryBarHeight) / 2)
        self.noImagesLabel.alpha = (height > threshold) ? 1 : (height - Dimensions.galleryBarHeight) / threshold
      }
    })
  }

  // MARK: - Photos handler

  func fetchPhotos(_ completion: (() -> Void)? = nil) {
    AssetManager.fetch(withConfiguration: configurations) { assets in
      self.assets.removeAll()
      self.assets.append(contentsOf: assets)
      self.collectionView.reloadData()

      completion?()
    }
  }

  // MARK: - Pan gesture recognizer

  @objc func handlePanGestureRecognizer(_ gesture: UIPanGestureRecognizer) {
    guard let superview = superview else { return }

    let translation = gesture.translation(in: superview)
    let velocity = gesture.velocity(in: superview)

    switch gesture.state {
    case .began:
      delegate?.panGestureDidStart()
    case .changed:
      delegate?.panGestureDidChange(translation)
    case .ended:
      delegate?.panGestureDidEnd(translation, velocity: velocity)
    default: break
    }
  }

  func displayNoImagesMessage(_ hideCollectionView: Bool) {
    collectionView.alpha = hideCollectionView ? 0 : 1
    updateNoImagesLabel()
  }
}

// MARK: CollectionViewFlowLayout delegate methods

extension ImageGalleryView: UICollectionViewDelegateFlowLayout {

  public func collectionView(_ collectionView: UICollectionView,
                             layout collectionViewLayout: UICollectionViewLayout,
                             sizeForItemAt indexPath: IndexPath) -> CGSize {
      guard let collectionSize = collectionSize else { return CGSize.zero }

      return collectionSize
  }
}

// MARK: CollectionView delegate methods

extension ImageGalleryView: UICollectionViewDelegate {

  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    guard let cell = collectionView.cellForItem(at: indexPath)
      as? ImageGalleryViewCell else { return }
    if configurations.allowMultiplePhotoSelection == false {
      // Clear selected photos array
      for asset in self.selectedStack.assets {
        self.selectedStack.dropAsset(asset)
      }
      // Animate deselecting photos for any selected visible cells
      guard let visibleCells = collectionView.visibleCells as? [ImageGalleryViewCell] else { return }
      for cell in visibleCells where cell.selectedImageView.image != nil {
        UIView.animate(withDuration: 0.2, animations: {
          cell.selectedImageView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        }, completion: { _ in
          cell.selectedImageView.image = nil
        })
      }
    }

    let asset = assets[(indexPath as NSIndexPath).row]

    AssetManager.resolveAsset(asset, size: CGSize(width: 100, height: 100), shouldPreferLowRes: configurations.useLowResolutionPreviewImage) { image in
      guard image != nil else { return }

      if cell.selectedImageView.image != nil {
        UIView.animate(withDuration: 0.2, animations: {
          cell.selectedImageView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
          }, completion: { _ in
            cell.selectedImageView.image = nil
        })
        self.selectedStack.dropAsset(asset)
        self.delegate?.itemTapped();
      } else if self.configurations.maxImages == 0 || self.configurations.maxImages > self.selectedStack.assets.count {
        cell.selectedImageView.image = AssetManager.getImage("selectedImageGallery")
        cell.selectedImageView.transform = CGAffineTransform(scaleX: 0, y: 0)
        UIView.animate(withDuration: 0.2, animations: {
          cell.selectedImageView.transform = CGAffineTransform.identity
        })
        self.selectedStack.pushAsset(asset)
        self.delegate?.itemTapped();
      }
    }
  }
}
