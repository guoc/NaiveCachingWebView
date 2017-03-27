//
//  URLRequest+Extension.swift
//  HoogleIt
//
//  Created by guoc on 26/03/2017.
//  Copyright © 2017 guoc. All rights reserved.
//

import Foundation

extension URLRequest {
    
    var requestByRemovingURLFragment: URLRequest {
        var request = self
        request.url = request.url?.urlByRemovingFragment
        return request
    }
}
