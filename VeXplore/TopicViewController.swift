//
//  TopicViewController.swift
//  VeXplore
//
//  Copyright © 2016 Jimmy. All rights reserved.
//


class TopicViewController: SwipeTransitionViewController, UIScrollViewDelegate, TopicDetailViewControllerDelegate, ReplyActivityDelegate, FavoriteActivityDelegate, IgnoreActivityDelegate, ReportActivityDelegate, OpenInSafariActivityDelegate
{
    private lazy var segmentedControl: SegmentControl = {
        let control = SegmentControl(titles: [R.String.Content, R.String.Comment], selectedIndex: 0)
        control.addTarget(self, action: #selector(segmentedControlValueChanged(sender:)), for: .valueChanged)

        return control
        
    }()
    
    private lazy var contentScrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        view.showsHorizontalScrollIndicator = false
        view.isPagingEnabled = true
        view.bounces = false
        view.scrollsToTop = false
        
        return view
    }()
    
    var ignoreHandler: IgnoreHandler?
    var unfavoriteHandler: UnfavoriteHandler?
    var topicId = R.String.Zero
    private let topicDetailVC = TopicDetailViewController()
    private let topicCommentVC = TopicCommentsViewController()
    private let inputVC = TopicReplyingViewController()
    private var activityViewController: UIActivityViewController?
    private var unfavorite = false
    private var enableReplying = false
    private weak var presentingVC: UIViewController?
    
    init()
    {
        super.init(nibName: nil, bundle: nil)
        dismissStyle = .right
        topicDetailVC.dismissStyle = .none
        topicCommentVC.dismissStyle = .none
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        view.addSubview(contentScrollView)
        let bindings = ["contentScrollView": contentScrollView]
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[contentScrollView]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: bindings))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[contentScrollView]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: bindings))
  
        let closeBtn = UIBarButtonItem(image: R.Image.Close, style: .plain, target: self, action: #selector(closeBtnTapped))
        closeBtn.tintColor = .middleGray
        navigationItem.leftBarButtonItem = closeBtn
        segmentedControl.frame = CGRect(x: 0, y: 0, width: 120, height: 26)
        navigationItem.titleView = segmentedControl
        
        contentScrollView.backgroundColor = .white
        view.backgroundColor = .offWhite
        setup()
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        presentingVC = navigationController?.presentingViewController?.childViewControllers.first
    }

    deinit
    {
        if unfavorite
        {
            unfavoriteHandler?(self.topicId)
        }
    }
    
    private func setup()
    {
        view.layoutIfNeeded()

        topicDetailVC.delegate = self
        topicDetailVC.inputVC = inputVC
        topicCommentVC.inputVC = inputVC
        topicDetailVC.topicId = topicId
        topicCommentVC.topicId = topicId
        
        addChildViewController(topicDetailVC)
        topicDetailVC.didMove(toParentViewController: self)
        topicDetailVC.view.frame = CGRect(x: 0, y: 0, width: contentScrollView.bounds.width, height: contentScrollView.bounds.height)
        contentScrollView.addSubview(topicDetailVC.view)

        addChildViewController(topicCommentVC)
        topicCommentVC.didMove(toParentViewController: self)
        topicCommentVC.view.frame = CGRect(x: contentScrollView.bounds.width, y: 0, width: contentScrollView.bounds.width, height: contentScrollView.bounds.height)
        contentScrollView.addSubview(topicCommentVC.view)
        
        contentScrollView.contentSize = CGSize(width: 2 * view.frame.width, height: 0)
    }
    
    // MARK: - TopicDetailViewControllerDelegate
    func showMoreIcon()
    {
        let moreBtn = UIBarButtonItem(image: R.Image.More, style: .plain, target: self, action: #selector(moreBtnTapped))
        moreBtn.tintColor = .middleGray
        navigationItem.rightBarButtonItem = moreBtn
        
        enableReplying = true
        setupActivityVC()
    }
    
    private func setupActivityVC()
    {
        var activityItems = [Any]()
        var applicationActivities = [UIActivity]()
        
        // activityItems
        let urlString = R.String.BaseUrl + "/t/" + topicId
        if let url = URL(string: urlString)
        {
            activityItems.append(url)
        }
        let title = topicDetailVC.topicDetailModel.topicTitle ?? R.String.NoTitle
        activityItems.append(title)
        
        // reply
        if User.shared.isLogin
        {
            let replyActivity = ReplyActivity()
            replyActivity.delegate = self
            applicationActivities.append(replyActivity)
            
            let favoriteActivity = FavoriteActivity()
            favoriteActivity.delegate = self
            applicationActivities.append(favoriteActivity)
        }
        
        //owner view
        let ownerViewActivity = OwnerViewActivity()
        ownerViewActivity.delegate = topicCommentVC
        applicationActivities.append(ownerViewActivity)
        topicCommentVC.ownername = topicDetailVC.topicDetailModel.username
        
        // ignore & report, report code is commented, just for app store review
        if User.shared.isLogin == true
        {
            if topicDetailVC.topicDetailModel.username != User.shared.username
            {
                let ignoreActivity = IgnoreActivity()
                ignoreActivity.delegate = self
                applicationActivities.append(ignoreActivity)
            }
            let reportActivity = ReportActivity()
            reportActivity.delegate = self
            applicationActivities.append(reportActivity)
        }
        
        // safari
        let openInSafariActivity = OpenInSafariActivity()
        openInSafariActivity.delegate = self
        applicationActivities.append(openInSafariActivity)
        
        activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        activityViewController!.excludedActivityTypes = [.addToReadingList, .message]
    }
    
    func isUnfavoriteTopic(_ unfavorite: Bool) // if unfavorite topic
    {
        self.unfavorite = unfavorite
    }
    
    // MARK: - Actions
    @objc
    private func closeBtnTapped()
    {
        dismiss(animated: true, completion: nil)
    }
    
    @objc
    private func moreBtnTapped()
    {
        activityViewController?.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(activityViewController!, animated: true, completion: nil)
    }
    
    // MARK: - ActivityDelegate
    func replyActivityTapped()
    {
        activityViewController?.dismiss(animated: true, completion: {
            self.inputVC.topicId = self.topicId
            self.present(self.inputVC, animated: true, completion: nil)
        })

    }
    
    func favoriteActivityTapped()
    {
        topicDetailVC.favoriteBtnTapped()
    }
    
    func ignoreActivityTapped()
    {
        V2Request.Topic.ignoreTopic(withTopicId: topicId, completionHandler: { [weak self] (response) -> Void in
            guard let weakSelf = self else {
                return
            }
            
            if response.success
            {
                weakSelf.dismiss(animated: true, completion: {
                    weakSelf.ignoreHandler?(weakSelf.topicId)
                })
            }
        })
    }
    
    func reportActivityTapped()
    {
//        guard let reportUrl = topicDetailVC.topicDetailModel.reportUrl else {
//            return
//        }
//        V2Request.Topic.reportTopic(withURL: reportUrl) { (response) -> Void in
//        }
        
        V2Request.Topic.fakeRequest()
    }
    
    func openInSafariActivityTapped()
    {
        let urlString = R.String.BaseUrl + "/t/" + topicId
        if let url = URL(string: urlString)
        {
            UIApplication.shared.openURL(url)
        }
    }
    
    func segmentedControlValueChanged(sender: SegmentControl)
    {
        showPage(atIndex: sender.selectedIndex, animated: true)
    }
    
    // MARK: - UIScrollViewDelegate
    override func scrollViewDidScroll(_ scrollView: UIScrollView)
    {
        super.scrollViewDidScroll(scrollView)
        if scrollView.isDragging || scrollView.isDecelerating
        {
            let offsetRate = contentScrollView.contentOffset.x / contentScrollView.bounds.width
            segmentedControl.indicatorOffset = offsetRate
        }
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView)
    {
        let index = Int(scrollView.contentOffset.x / scrollView.frame.width)
        showPage(atIndex: index, animated: true)
        scrollView.panGestureRecognizer.isEnabled = true
    }
    
    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView)
    {
        super.scrollViewDidEndDecelerating(scrollView)
        let index = Int(scrollView.contentOffset.x / scrollView.frame.width)
        if scrollView.contentOffset.x >= 0, scrollView.contentOffset.x + scrollView.frame.width <= scrollView.contentSize.width
        {
            showPage(atIndex: index, animated: true)
        }
        scrollView.panGestureRecognizer.isEnabled = true
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView)
    {
        if scrollView.isDecelerating
        {
            scrollView.panGestureRecognizer.isEnabled = false
        }
    }
    
    // MARK: - Private
    private func showPage(atIndex index: Int, animated: Bool)
    {
        segmentedControl.setSelectedIndex(index)
        let offsetX = contentScrollView.bounds.width * CGFloat(index)
        contentScrollView.setContentOffset(CGPoint(x: offsetX, y: 0.0), animated: animated)
        if index == 0
        {
            topicDetailVC.tableView.scrollsToTop = true
            topicCommentVC.tableView.scrollsToTop = false
        }
        else if index == 1
        {
            topicDetailVC.tableView.scrollsToTop = false
            topicCommentVC.tableView.scrollsToTop = true
        }
    }
    
    // MARK: - Shake
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?)
    {
        guard User.shared.isLogin, enableReplying else{
            return
        }
        
        if motion == .motionShake
        {
            let preferences = UserDefaults.standard
            let enableShake = preferences.object(forKey: R.Key.EnableShake) as? NSNumber
            if enableShake?.boolValue != false
            {
                inputVC.topicId = topicId
                present(inputVC, animated: true, completion: nil)
            }
        }
    }

}
