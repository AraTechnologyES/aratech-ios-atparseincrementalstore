//
//  NSManagedObject.swift
//  ATParseIncrementalStore
//
//  Created by Nicolás Landa on 19/7/18.
//  Copyright © 2018 Aratech. All rights reserved.
//

import Parse
import CoreData

extension NSManagedObject {
	
	func fill(with backup: NSManagedObject) {
		for (key, _) in self.entity.propertiesByName {
			let value = backup.value(forKey: key)
			self.setValue(value, forKey: key)
		}
	}
	
	func fill(with pfObject: PFObject) {
//		self.setValue(pfObject.objectId, forKey: AugmentedModelAttributeKey.objectId)
//		self.setValue(pfObject.createdAt, forKey: AugmentedModelAttributeKey.createdAt)
//		self.setValue(pfObject.updatedAt, forKey: AugmentedModelAttributeKey.updatedAt)
	}
}
