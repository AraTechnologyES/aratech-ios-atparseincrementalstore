//
//  OSLog.swift
//  ATParseIncrementalStore
//
//  Created by Nicolás Landa on 24/7/18.
//  Copyright © 2018 Aratech. All rights reserved.
//

import os

private typealias Categories = String

private extension Categories {
	static let newValuesForObject = "newValuesForObject"
	static let parseFetch = "parseFetch"
	static let rowCache = "RowCache"
}

extension OSLog {
	static let atParseIncrementalStore = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "")
	static let newValuesForObject: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: .newValuesForObject)
	static let parseFetch: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: .parseFetch)
	static let rowCache: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: .rowCache)
}
