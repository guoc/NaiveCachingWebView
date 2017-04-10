//
//  WKWebView+NaiveCachingWebView.swift
//  HoogleIt
//
//  Created by guoc on 25/03/2017.
//  Copyright © 2017 guoc. All rights reserved.
//

import Foundation
import WebKit

public typealias CachingCompletionHandler = (_ cachedRequest: URLRequest, _ canceled: Bool) -> Void

public extension WKWebView {

    @discardableResult public func cachingLoad(_ request: URLRequest) -> WKNavigation? {
        
        return cachingLoad(request, with: nil)
    }

    // TODO: Add @escaping for cachingCompletionHandler. Now it has been considered as @escaping, see [Optional closure type is always considered @escaping](https://bugs.swift.org/browse/SR-2324)
    @discardableResult public func cachingLoad(_ request: URLRequest, options: CachingOptions = [], with htmlProcessors: HTMLProcessorsProtocol? = nil, cachingCompletionHandler: CachingCompletionHandler? = nil) -> WKNavigation? {
        
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

        if options.contains(.ignoreExistingCache) {

            print("CachingOptions.ignoreExistingCache is applied.")

        } else if WKWebView.hasCached(for: request) {

            let navigation = loadWithCache(for: request)
            if options.contains(.rebuildCache) {
                print("CachingOptions.rebuildCache is applied.")
                WKWebView.cache(request, with: htmlProcessors, cachingCompletionHandler: cachingCompletionHandler)
            } else {
                // TODO: In this case, cachingCompletionHandler is non-escape, should it be consistent with other cases by wrapping it with an async?
                cachingCompletionHandler?(request, false)
            }
            return navigation

        } else {

            print("No cache found.")
        }
        
        let navigation = load(request)

        if options.contains(.rebuildCache) {
            print("CachingOptions.rebuildCache is applied.")
            WKWebView.cache(request, with: htmlProcessors, cachingCompletionHandler: cachingCompletionHandler)
        } else {
            // TODO: In this case, cachingCompletionHandler is non-escape, should it be consistent with other cases by wrapping it with an async?
            cachingCompletionHandler?(request, false)
        }

        return navigation
    }

    public class func hasCached(for request: URLRequest) -> Bool {

        guard let cacheInfo = cacheInfo(for: request) else {
            return false
        }
        precondition(cacheInfo.naiveCachingWebViewCached, "Unexpected naiveCachingWebViewCached \(cacheInfo.naiveCachingWebViewCached), it should always be true.")
        return true
    }

    public class func cacheInfo(for request: URLRequest) -> CacheInfo? {

        let userInfo = URLCache.shared.cachedResponse(for: request.requestByRemovingURLFragment)?.userInfo
        let cacheInfo = CacheInfo(from: userInfo)
        return cacheInfo
    }

    @discardableResult public class func cache(_ request: URLRequest, startAutomatically startFlag: Bool = true, with htmlProcessors: HTMLProcessorsProtocol? = nil, cachingCompletionHandler: CachingCompletionHandler? = nil) -> Operation {

        let cacheOperation = CachingOperation(request, with: htmlProcessors, cachingCompletionHandler: cachingCompletionHandler)
        if startFlag {
            cacheOperation.start()
        }
        return cacheOperation
    }

    internal static let userAgent: String = {

        // TODO: figure out why:
        // if CFRunLoopRun() is waiting for function A, A can not call CFRunLoopRun(), otherwise waiting forever.

        // Init in main thread, otherwise evaluateJavaScript's completionHandler might not be in main thread as the document said,
        // that will cause the following WKWebView's load method not working (navigationDelegate methods not called).
        var webView: WKWebView!

        var userAgent: String!

        let dispatchGroup = DispatchGroup()

        if Thread.isMainThread {
            webView = WKWebView(frame: .zero)
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
                RunLoop.current.run(until: Date() + 0.25)
            }
        } else {
            DispatchQueue.main.async(group: dispatchGroup) {
                webView = WKWebView(frame: .zero)
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
            }
            dispatchGroup.wait()
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
        
        print("The cache of \(request.requestByRemovingURLFragment.url?.description ?? "nil URL") is applied for \(url).")
        
        return navigation
    }

    internal class func plainHTML(for request: URLRequest) -> String? {
        
        let htmlDispatchGroup = DispatchGroup()
        
        var htmlString: String?
        
        htmlDispatchGroup.enter()
        
        URLSession(configuration: .default).dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            
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
    
    internal class func inlineResources(for plainHTML: String, with baseURL: URL) -> String {
        
        var newHTMLString = plainHTML
        
        newHTMLString = WKWebView.stringByInliningStyles(for: newHTMLString, with: baseURL)
        newHTMLString = WKWebView.stringByInliningScripts(for: newHTMLString, with: baseURL)
        newHTMLString = WKWebView.stringByInliningImages(for: newHTMLString, with: baseURL)
        
        print("CSS and JavaScript inlining finished.")

        return newHTMLString
    }
    
    private class func stringByInliningStyles(for fileContent: String, with baseURL: URL) -> String {
        
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
    
    private class func stringByInliningScripts(for fileContent: String, with baseURL: URL) -> String {
        
        let scriptTagPairPatternWithoutContent = try! NSRegularExpression(pattern: "<script [^>]*src=\\\"(?!https?:\\/\\/)(\\S+)\\\"[^<>]*>\\s*<\\/script>")

        let scriptTagTemplateGenerator = { (fileName: String, originalTag: String) -> String in
            originalTag.replacingOccurrences(of: "src=\\\"[^\\\"]*\\\"", with: "", options: .regularExpression)
                .replacingOccurrences(of: "</script>", with: "")
                + "\n%@\n</script>"
        }
        
        let newFileContent = WKWebView.replace(tagPattern: scriptTagPairPatternWithoutContent
            , withFileNameCapturingGroup: 1
            , for: fileContent
            , baseURL: baseURL
            , newTagTemplateGenerator: scriptTagTemplateGenerator)

        return newFileContent
    }
    
    private class func stringByInliningImages(for fileContent: String, with baseURL: URL) -> String {
        
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
        
        let newFileContent = WKWebView.replace(tagPattern: urlFunctionalNotationPattern
            , withFileNameCapturingGroup: 1
            , for: fileContent
            , baseURL: baseURL
            , newTagTemplateGenerator: base64ImageURLTemplateGenerator
            , rawDataHandler: imageRawDataHandler)
        
        return newFileContent
    }
    
    private class func replace(tagPattern: NSRegularExpression
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

internal extension String {
    
    internal var stringByRemovingSlashStarComments: String {
        get {
            return replacingOccurrences(of: "\\/\\*.*\\*\\/", with: "", options: .regularExpression)
        }
    }
}
