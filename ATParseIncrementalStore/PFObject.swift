//
//  PFObject.swift
//  ATParseIncrementalStore
//
//  Created by Nicolás Landa on 24/7/18.
//  Copyright © 2018 Aratech. All rights reserved.
//

import Parse
import CoreData

extension PFObject {
	
	/// - Returns: Todos los valores no nulos
	var allValues: [String: Any] {
		return values(for: self.allKeys)
	}
	
	/// Valores para las claves provistas
	///
	/// - Parameter keys: Claves de las que se desean los valores
	/// - Returns: Valores asociados a las claves, de existir
	func values(for keys: [String]) -> [String: Any] {
		if self.isDataAvailable {
			let valuesPairs: [(String, Any)] = keys.compactMap({
				if let property = self.object(forKey: $0) as? PFFile,
					let url = property.url {
					return ($0, url)
				} else if let property = self.object(forKey: $0) {
					return ($0, property)
				} else {
					return nil
				}
			})
			
			return Dictionary(uniqueKeysWithValues: valuesPairs)
		} else {
			return [:]
		}
	}
}
