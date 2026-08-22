import UIKit

class StatisticsCell: UITableViewCell {
    
    static let statisticsCellIdentifier = "statisticsCell"
    
    private lazy var countLabel: UILabel = {
        let label = UILabel()
        label.font = .ladomiBold(36)
        label.textColor = .ypBlack
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.72
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .ladomiBold(16)
        label.textColor = .ypBlack
        label.numberOfLines = 1
        return label
    }()

    private lazy var detailLabel: UILabel = {
        let label = UILabel()
        label.font = .ladomiMedium(13)
        label.textColor = .ypLightGray
        label.numberOfLines = 3
        return label
    }()
    
    private lazy var gradientBorderView: GradientBorderView = {
        let view = GradientBorderView()
        return view
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .none
        selectionStyle = .none
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    }
    
    func configureCell(with title: String, value: String) {
        configureCell(with: title, value: value, detail: nil)
    }

    func configureCell(with title: String, value: String, detail: String?) {
        titleLabel.text = title
        countLabel.text = value
        detailLabel.text = detail

        let containsLetters = value.rangeOfCharacter(from: .letters) != nil
        let valueFontSize: CGFloat = containsLetters ? 30 : 36
        countLabel.font = .ladomiBold(valueFontSize)
    }
    
    private func setupUI() {
        
        [gradientBorderView,
         titleLabel,
         detailLabel,
         countLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        contentView.backgroundColor = .ypWhite
        
        NSLayoutConstraint.activate([
            gradientBorderView.topAnchor.constraint(equalTo: contentView.topAnchor),
            gradientBorderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            gradientBorderView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            gradientBorderView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            countLabel.topAnchor.constraint(equalTo: gradientBorderView.topAnchor, constant: 12),
            countLabel.leadingAnchor.constraint(equalTo: gradientBorderView.leadingAnchor, constant: 12),
            countLabel.trailingAnchor.constraint(lessThanOrEqualTo: gradientBorderView.trailingAnchor, constant: -12),
            
            titleLabel.leadingAnchor.constraint(equalTo: gradientBorderView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: gradientBorderView.trailingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 6),

            detailLabel.leadingAnchor.constraint(equalTo: gradientBorderView.leadingAnchor, constant: 12),
            detailLabel.trailingAnchor.constraint(equalTo: gradientBorderView.trailingAnchor, constant: -12),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: gradientBorderView.bottomAnchor, constant: -12)
        ])
    }
}
