import UIKit

protocol ButtonPickerDelegate: class {

  func buttonDidPress()
}

class ButtonPicker: UIButton {

  struct Dimensions {
    static let borderWidth: CGFloat = 2
    static let buttonSize: CGFloat = 58
    static let buttonBorderSize: CGFloat = 68
  }

  var configurations = Configurations()

  lazy var numberLabel: UILabel = { [unowned self] in
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = self.configurations.numberLabelFont

    return label
    }()

  weak var delegate: ButtonPickerDelegate?

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

  func configure() {
    addSubview(numberLabel)

    subscribe()
    setupButton()
    setupConstraints()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  func subscribe() {
    NotificationCenter.default.addObserver(self,
      selector: #selector(recalculatePhotosCount(_:)),
      name: NSNotification.Name(rawValue: ImageStack.Notifications.imageDidPush),
      object: nil)

    NotificationCenter.default.addObserver(self,
      selector: #selector(recalculatePhotosCount(_:)),
      name: NSNotification.Name(rawValue: ImageStack.Notifications.imageDidDrop),
      object: nil)

    NotificationCenter.default.addObserver(self,
      selector: #selector(recalculatePhotosCount(_:)),
      name: NSNotification.Name(rawValue: ImageStack.Notifications.stackDidReload),
      object: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Configurations

  func setupButton() {
    backgroundColor = UIColor.white
    layer.cornerRadius = Dimensions.buttonSize / 2
    accessibilityLabel = "Take photo"
    addTarget(self, action: #selector(pickerButtonDidPress(_:)), for: .touchUpInside)
    addTarget(self, action: #selector(pickerButtonDidHighlight(_:)), for: .touchDown)
  }

  // MARK: - Actions

  @objc func recalculatePhotosCount(_ notification: Notification) {
    guard let sender = notification.object as? ImageStack else { return }
      print("imageLimit: \(self.configurations.maxImages), assets: \(sender.assets.count)")
    
      if (self.configurations.maxImages == 1) {
          if (sender.assets.count == 1) {
              numberLabel.text = "x"
              numberLabel.font = numberLabel.font.withSize(25)
          } else {
              numberLabel.text = ""
              numberLabel.font = self.configurations.numberLabelFont
          }
      } else { // multiple image selections
          numberLabel.text = sender.assets.isEmpty ? "" : String(sender.assets.count)
      }
    
    
  }

  @objc func pickerButtonDidPress(_ button: UIButton) {
    backgroundColor = UIColor.white
    numberLabel.textColor = UIColor.black
    numberLabel.sizeToFit()
    delegate?.buttonDidPress()
  }

  @objc func pickerButtonDidHighlight(_ button: UIButton) {
    numberLabel.textColor = UIColor.white
    backgroundColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1)
  }
}
