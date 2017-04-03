//
//  WKWebView+NaiveCachingWebView.swift
//  HoogleIt
//
//  Created by guoc on 25/03/2017.
//  Copyright © 2017 guoc. All rights reserved.
//

import Foundation
import WebKit

public protocol HTMLProcessorsProtocol {
    
    var preprocessor: ((String) -> String)? { get }
    var postprocessor: ((String) -> String)? { get }
}

public struct HTMLProcessors: HTMLProcessorsProtocol {
    
    public let preprocessor: ((String) -> String)?
    public let postprocessor: ((String) -> String)?

    public init(preprocessor: ((String) -> String)?, postprocessor: ((String) -> String)?) {
        self.preprocessor = preprocessor
        self.postprocessor = postprocessor
    }
}

public extension WKWebView {
        
    private static let session = URLSession(configuration: .default)
    
    public func cachingLoad(_ request: URLRequest) -> WKNavigation? {
        
        return cachingLoad(request, with: nil)
    }
    
    public func cachingLoad(_ request: URLRequest, with htmlProcessors: HTMLProcessorsProtocol? = nil, cachingCompletionHanlder: (() -> Void)? = nil) -> WKNavigation? {
        
        guard !isLoading else {
            print("Web view is loading, stop further loadWithCache.")
            return nil
        }
        
        guard let url = request.url else {
            assertionFailure("Expected non-nil URL in request \(request).")
            return nil
        }

        if let fragment = url.fragment {
            setupScrollToFragmentScript(with: fragment)
        }

        if let navigation = loadWithCache(for: request) {
            cachingCompletionHanlder?()
            return navigation
        }
        
        print("No cache found, try to load, and cache.")
        
        let navigation = load(request)
        
        cache(request, with: htmlProcessors, cachingCompletionHanlder: cachingCompletionHanlder)

        return navigation
    }

    public class func hasCached(for request: URLRequest) -> Bool {

        return URLCache.shared.cachedResponse(for: request.requestByRemovingURLFragment) != nil
    }

    public func cache(_ request: URLRequest, with htmlProcessors: HTMLProcessorsProtocol? = nil, cachingCompletionHanlder: (() -> Void)? = nil) {

        DispatchQueue.global(qos: .utility).async {

            self.cacheInlinedWebPage(for: request, with: htmlProcessors)
            cachingCompletionHanlder?()
        }
    }

    private static let userAgent: String = {
        
        var userAgent: String!
        
        let window = UIWindow(frame: UIScreen.main.bounds)
        let webView = WKWebView(frame: window.bounds)
        window.addSubview(webView)
        
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        webView.evaluateJavaScript("navigator.userAgent") { (result: Any?, error: Error?) in
            guard error == nil else {
                preconditionFailure(error!.localizedDescription)
            }
            guard let result = result as? String else {
                preconditionFailure("Failed to get user agent.")
            }
            userAgent = result
            dispatchGroup.leave()
        }
        while dispatchGroup.wait(timeout: .now()) == .timedOut {
            RunLoop.main.run(until: Date() + 0.25)
        }
        
        return userAgent
    }()

    
    private func loadWithCache(for request: URLRequest) -> WKNavigation? {

        guard WKWebView.hasCached(for: request) else {
            print("No cache found for \(String(describing: request.url)).")
            return nil
        }
        
        guard let cachedResponse = URLCache.shared.cachedResponse(for: request.requestByRemovingURLFragment) else {
            preconditionFailure("hasCached(for:) return true but no cache found for \(String(describing: request.url)).")
        }
        
        let response = cachedResponse.response
        let mimeType = response.mimeType ?? "text/html"
        let encodingName = response.textEncodingName ?? "UTF-8"
        guard let url = request.url else {
            assertionFailure("Expected non-nil URL in request \(request).")
            return nil
        }
        let baseURL = url.urlByRemovingFragment
        
        let navigation = load(cachedResponse.data, mimeType: mimeType, characterEncodingName: encodingName, baseURL: baseURL)
        
        print("The cache for \(url) is applied.")
        
        return navigation
    }
    
    private func cacheInlinedWebPage(for request: URLRequest, with htmlProcessors: HTMLProcessorsProtocol?) {
        
        let request: URLRequest = {
            var request = request
            request.setValue(WKWebView.userAgent, forHTTPHeaderField: "User-Agent")
            return request
        }()

        guard let plainHTMLString = plainHTML(for: request) else {
            assertionFailure("Failed to fetch the plain HTML for \(String(describing: request.url))")
            return
        }
        
        let preprocessedHTMLString = htmlProcessors?.preprocessor?(plainHTMLString) ?? plainHTMLString
        
        guard let url = request.url else {
            assertionFailure("Expected non-nil URL in request \(request).")
            return
        }
        let baseURL = url.deletingLastPathComponent()
        
        let inlinedHTMLString = inlineResources(for: preprocessedHTMLString, with: baseURL)
        
        let postprocessedHTMLString = htmlProcessors?.postprocessor?(inlinedHTMLString) ?? inlinedHTMLString
        
#if SAVE_INLINED_PAGE_FOR_TESTING
        let targetPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("NaiveCachingWebView", isDirectory: true)
            .appendingPathComponent("InlinedPages", isDirectory: true)
            .appendingPathComponent(url.absoluteString.replacingOccurrences(of: "^https?:\\/\\/", with: "", options: .regularExpression) + ".html")
        do {
            try FileManager.default.createDirectory(at: targetPath.deletingLastPathComponent(), withIntermediateDirectories: true)
            print("Try to save inlined page file to \(targetPath)")
            try postprocessedHTMLString.write(to: targetPath, atomically: true, encoding: .utf8)
        } catch {
            assertionFailure("Failed to save inlined page file.")
        }
#endif
        
        let newCachedResponse: CachedURLResponse = {
            let response = URLResponse(url: url, mimeType: "text/html", expectedContentLength: postprocessedHTMLString.characters.count, textEncodingName: "UTF-8")
            guard let data = postprocessedHTMLString.data(using: .utf8) else {
                preconditionFailure("Failed to convert HTML string to data.")
            }
            return CachedURLResponse(response: response, data: data)
        }()
        
        URLCache.shared.storeCachedResponse(newCachedResponse, for: request.requestByRemovingURLFragment)
        
        print("Cache stored for \(request.requestByRemovingURLFragment.url?.absoluteString ?? "nil url").")
    }

    private func plainHTML(for request: URLRequest) -> String? {
        
        let htmlDispatchGroup = DispatchGroup()
        
        var htmlString: String?
        
        htmlDispatchGroup.enter()
        
        WKWebView.session.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            
            guard error == nil else {
                assertionFailure("Error: \(error!.localizedDescription)")
                htmlDispatchGroup.leave()
                return
            }
            
            if let response = response as? HTTPURLResponse {
                if response.statusCode != 200 {
                    assertionFailure("Response error: \(response.statusCode)(\(HTTPURLResponse.localizedString(forStatusCode: response.statusCode))).")
                    htmlDispatchGroup.leave()
                    return
                }
            } else {
                print("The response is not HTTPURLResponse type.")
            }
            
            guard let data = data else {
                assertionFailure("Expected response data.")
                htmlDispatchGroup.leave()
                return
            }
            
            let encoding = response?.stringEncoding ?? .utf8
            htmlString = String(data: data, encoding: encoding)
            
            htmlDispatchGroup.leave()
            
        }.resume()
        
        htmlDispatchGroup.wait()
        
        return htmlString
    }
    
    private func inlineResources(for plainHTML: String, with baseURL: URL) -> String {
        
        var newHTMLString = plainHTML
        
        newHTMLString = stringByInliningStyles(for: newHTMLString, with: baseURL)
        newHTMLString = stringByInliningScripts(for: newHTMLString, with: baseURL)
        newHTMLString = stringByInliningImages(for: newHTMLString, with: baseURL)
        
        print("CSS and JavaScript inlining finished.")

        return newHTMLString
    }
    
    private func stringByInliningStyles(for fileContent: String, with baseURL: URL) -> String {
        
        let linkTagPattern = try! NSRegularExpression(pattern: "<link [^>]*href=\\\"(\\S+\\.css)\\\"[^<>]+\\/>")

        let styleTagTemplateGenerator = { (fileName: String, originalTag: String) -> String in
            originalTag.replacingOccurrences(of: "<link", with: "<style")
                .replacingOccurrences(of: "href=\\\"[^\\\"]*\\\"", with: "", options: .regularExpression)
                .replacingOccurrences(of: "/ *>", with: ">", options: .regularExpression)
                + "\n%@\n</style>"
        }
        
        let newFileContent = replace(tagPattern: linkTagPattern
            , withFileNameCapturingGroup: 1
            , for: fileContent
            , baseURL: baseURL
            , newTagTemplateGenerator: styleTagTemplateGenerator)

        return newFileContent
    }
    
    private func stringByInliningScripts(for fileContent: String, with baseURL: URL) -> String {
        
        let scriptTagPairPatternWithoutContent = try! NSRegularExpression(pattern: "<script [^>]*src=\\\"(?!https?:\\/\\/)(\\S+)\\\"[^<>]*>\\s*<\\/script>")

        let scriptTagTemplateGenerator = { (fileName: String, originalTag: String) -> String in
            originalTag.replacingOccurrences(of: "src=\\\"[^\\\"]*\\\"", with: "", options: .regularExpression)
                .replacingOccurrences(of: "</script>", with: "")
                + "\n%@\n</script>"
        }
        
        let newFileContent = replace(tagPattern: scriptTagPairPatternWithoutContent
            , withFileNameCapturingGroup: 1
            , for: fileContent
            , baseURL: baseURL
            , newTagTemplateGenerator: scriptTagTemplateGenerator)

        return newFileContent
    }
    
    private func stringByInliningImages(for fileContent: String, with baseURL: URL) -> String {
        
        let urlFunctionalNotationPattern = try! NSRegularExpression(pattern: "url\\(([^:\\s)]+)\\)")

        let base64ImageURLTemplateGenerator = { (fileName: String, originalTag: String) -> String in
            guard let fileExtension = URL(string: fileName)?.pathExtension else {
                preconditionFailure("Failed to get \(fileName)'s file extension.")
            }
            return "url(\"data:image/\(fileExtension);base64,%@\")"
        }
        
        let imageRawDataHandler = { (rawData: Data) -> String in
            rawData.base64EncodedString(options: .lineLength64Characters).replacingOccurrences(of: "\r\n", with: "")
        }
        
        let newFileContent = replace(tagPattern: urlFunctionalNotationPattern
            , withFileNameCapturingGroup: 1
            , for: fileContent
            , baseURL: baseURL
            , newTagTemplateGenerator: base64ImageURLTemplateGenerator
            , rawDataHandler: imageRawDataHandler)
        
        return newFileContent
    }
    
    private func replace(tagPattern: NSRegularExpression
                       , withFileNameCapturingGroup idx: Int
                       , for fileContent: String
                       , baseURL: URL
                       , newTagTemplateGenerator: @escaping (_ fileName: String, _ originalTag: String) -> String
                       , rawDataHandler: ((_ rawData: Data) -> String)? = nil)
                       -> String
    {
        
        let dispatchGroup = DispatchGroup()
        
        var newFileContent = fileContent.stringByRemovingSlashStarComments
        
        let range = newFileContent.nsRange(from: newFileContent.startIndex..<newFileContent.endIndex)
        
        let fileNamesWithTag = tagPattern.matches(in: newFileContent, options: [], range: range).map { (match) -> (String, String) in
            let fileName = newFileContent.substring(with: newFileContent.range(from: match.rangeAt(idx)))
            let tag = newFileContent.substring(with: newFileContent.range(from: match.range))
            return (fileName, tag)
        }

        // Create local session to avoid block.
        let session = URLSession(configuration: .default)
        
        defer {
            session.finishTasksAndInvalidate()
        }
        
        for case (let fileName, let originalTag) in fileNamesWithTag {
            
            let baseURL: URL = {
                if fileName.hasPrefix("/") {
                    guard let host = baseURL.host, let hostURL = URL(string: "https://\(host)") else {
                        preconditionFailure("Failed to get host URL from \(baseURL).")
                    }
                    return hostURL
                } else {
                    return baseURL
                }
            }()
            
            guard let resourceFileURL = URL(string: fileName, relativeTo: baseURL) else {
                assertionFailure("Failed to get resource file \(fileName)'s URL.")
                continue
            }
            
            dispatchGroup.enter()
            
            session.dataTask(with: resourceFileURL) { (data: Data?, response: URLResponse?, error: Error?) in
                
                guard error == nil else {
                    assertionFailure("Error: \(error!.localizedDescription)")
                    dispatchGroup.leave()
                    return
                }
                
                guard let response = response as? HTTPURLResponse else {
                    assertionFailure("Expected a response with HTTPURLResponse type")
                    dispatchGroup.leave()
                    return
                }
                guard response.statusCode == 200 else {
                    print("Response error: \(HTTPURLResponse.localizedString(forStatusCode: response.statusCode))")
                    print("Failed to fetch resource file: \(resourceFileURL) ...")
                    dispatchGroup.leave()
                    return
                }
                guard let data = data else {
                    assertionFailure("Expected response data")
                    dispatchGroup.leave()
                    return
                }

                guard let originalTagRange = newFileContent.range(of: originalTag) else {
                    assertionFailure("Failed to find \(originalTag) in the file content.")
                    return
                }
    
                let rawDataHandler = rawDataHandler ?? { (_ rawData: Data) -> String in
                    let encoding = response.stringEncoding ?? .utf8
                    guard let resourceContent = String(data: data, encoding: encoding) else {
                        preconditionFailure("Failed to convert data to String")
                    }
                    return resourceContent
                }
    
                let resourceContent = rawDataHandler(data)
                
                let inlinedResourceContent = self.stringByInliningImages(for: resourceContent, with: resourceFileURL.deletingLastPathComponent())
    
                let newTagTemplate = newTagTemplateGenerator(fileName, originalTag)
                
                let newTag = String(format: newTagTemplate, inlinedResourceContent)
                
                newFileContent = newFileContent.replacingCharacters(in: originalTagRange, with: newTag)
                
                dispatchGroup.leave()
                
            }.resume()
        }
        
        dispatchGroup.wait()

        return newFileContent
    }

}

private extension String {
    
    var stringByRemovingSlashStarComments: String {
        get {
            return replacingOccurrences(of: "\\/\\*.*\\*\\/", with: "", options: .regularExpression)
        }
    }
}
