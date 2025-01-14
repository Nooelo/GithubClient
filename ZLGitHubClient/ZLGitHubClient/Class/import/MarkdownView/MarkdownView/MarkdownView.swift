import UIKit
import WebKit

/**
 Markdown View for iOS.
 
 - Note: [How to get height of entire document with javascript](https://stackoverflow.com/questions/1145850/how-to-get-height-of-entire-document-with-javascript)
 */
open class MarkdownView: UIView {

   var webView: WKWebView?
  
  fileprivate var intrinsicContentHeight: CGFloat? {
    didSet {
      self.invalidateIntrinsicContentSize()
    }
  }

  public var isScrollEnabled: Bool = true {

    didSet {
      webView?.scrollView.isScrollEnabled = isScrollEnabled
    }

  }

  public var onTouchLink: ((URLRequest) -> Bool)?

  public var onRendered: ((CGFloat) -> Void)?

  public convenience init() {
    self.init(frame: CGRect.zero)
  }

  override init (frame: CGRect) {
    super.init(frame : frame)
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
    

  open override var intrinsicContentSize: CGSize {
    if let height = self.intrinsicContentHeight {
      return CGSize(width: UIView.noIntrinsicMetric, height: height)
    } else {
      return CGSize.zero
    }
  }

    public func load(markdown: String?, baseUrl: String?, enableImage: Bool = true) {
        guard let markdown = markdown else { return }
        
        let bundle = Bundle.main
        
        let htmlURL: URL? =
            bundle.url(forResource: "index",
                       withExtension: "html") ??
                bundle.url(forResource: "index",
                           withExtension: "html",
                           subdirectory: "MarkdownView.bundle")
        
        if let url = htmlURL {
            
            if self.webView != nil
            {
                self.webView?.removeFromSuperview()
                self.webView = nil
            }
            
            let controller = WKUserContentController()
            
            let escapedMarkdown = self.escape(markdown: markdown) ?? ""
            let imageOption = enableImage ? "true" : "false"
            let script = "window.showMarkdown('\(escapedMarkdown)', \(imageOption));"
            let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            controller.addUserScript(userScript)
            
            // 对于相对路径的图片，修正为绝对路径
            if let tmpBaseUrl = baseUrl
            {
                let addBaseScript = "let a = '\(tmpBaseUrl)';let contentDiv = document.getElementById('contents');let array = contentDiv.getElementsByTagName('img');for(i=0;i<array.length;i++){let item=array[i];if(item.getAttribute('src').indexOf('http') == -1){item.src = a + item.getAttribute('src');}}"
                let addBaseUserScript = WKUserScript(source: addBaseScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
                controller.addUserScript(addBaseUserScript)
            }
            
            let configuration = WKWebViewConfiguration()
            configuration.userContentController = controller
            
            let wv = WKWebView(frame: self.bounds, configuration: configuration)
            wv.scrollView.isScrollEnabled = self.isScrollEnabled
            wv.translatesAutoresizingMaskIntoConstraints = false
            wv.navigationDelegate = self
            addSubview(wv)
            wv.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
            wv.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
            wv.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
            wv.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
            wv.backgroundColor = self.backgroundColor
            self.webView = wv
            
            do {
                let htmlStr = try String.init(contentsOf: url)
                self.webView?.loadHTMLString(htmlStr as String, baseURL: nil)
                
            }catch{
                self.webView?.loadHTMLString("Error", baseURL: nil)
            }
            
            

        } else {
            // TODO: raise error
        }
    }

  private func escape(markdown: String) -> String? {
    return markdown.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)
  }

}

extension MarkdownView: WKNavigationDelegate {

  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    let script = "document.body.scrollHeight;"
    webView.evaluateJavaScript(script) { [weak self] result, error in
      if let _ = error { return }

      if let height = result as? CGFloat {
        self?.onRendered?(height)
        self?.intrinsicContentHeight = height
      }
    }
  }

  public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

    switch navigationAction.navigationType {
    case .linkActivated:
      if let onTouchLink = onTouchLink, onTouchLink(navigationAction.request) {
        decisionHandler(.allow)
      } else {
        decisionHandler(.cancel)
      }
    default:
      decisionHandler(.allow)
    }

  }

}
