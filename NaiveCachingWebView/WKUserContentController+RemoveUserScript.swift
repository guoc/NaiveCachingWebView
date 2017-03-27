//
//  WKUserContentController+RemoveUserScript.swift
//  HoogleIt
//
//  Created by guoc on 25/03/2017.
//  Copyright © 2017 guoc. All rights reserved.
//

import Foundation
import WebKit

extension WKUserContentController {
    
    func removeUserScript(_ userScript: WKUserScript) {
        let newUserScripts = userScripts.filter({$0 != userScript})
        removeAllUserScripts()
        for case let newUserScript in newUserScripts {
            addUserScript(newUserScript)
        }
    }
}
